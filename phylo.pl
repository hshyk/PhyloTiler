#!/usr/bin/perl
use strict;
use warnings;
use lib "lib"; 
use Bio::Phylo::Factory;
use Bio::Phylo::Treedrawer;
use Bio::Phylo::IO 'parse_tree';
use Bio::Phylo::IO 'parse';
use XML::Simple;
use Image::Magick;
use File::Path;
use File::Copy;
use Config;
use JSON;

# Grab the Tree Input File
my $treefile  = shift @ARGV;
die "Need input file" if not -f $treefile;

# Grab the metadata input file
my $datafile  = shift @ARGV;
die "Need data file" if not -f $datafile;


# Create the XML object
my $xml = new XML::Simple;

# Read the configuration file
my $config = $xml->XMLin("config.xml");

# Need to configure this first so that we instantiate
# the right objects when parsing the newick string
my $fac = Bio::Phylo::Factory->new(
    'node' => 'Bio::Phylo::Forest::DrawNode',
    'tree' => 'Bio::Phylo::Forest::DrawTree',
);

# Create the image tiles
my $tilelevel = 0;
my $treesize = 8 ** $config->{size}->{zoom}->{maximum};

# Instantiate tree drawer
my $drawer = Bio::Phylo::Treedrawer->new(
    '-width'  => $config->{size}->{tree},
    '-height' => $config->{size}->{tree},
    # Args    : Options: [rect|diag|curvy|radial]
    '-shape'  => $config->{shape}, # rectangular tree
    '-mode'   => 'CLADO', # cladogram
    '-format' => 'SVG'
);

# Check the format of the file (Nexus or NeXML)
my ($ext) = $treefile =~ /(\.[^.]+)$/;
my $format = 0;
if ($ext eq '.xml') {
	$format = 'nexml';
}
elsif($ext eq '.tre') {
	$format = 'nexus';
}

die 'The format of your input file could not determined' unless $format ne 0;

# Import a tree from a NeXML file
my $tree;
BLOCK: for my $block ( @{ parse( '-format' => $format, '-file' => $treefile ) } ) {
	if ( $block->isa('Bio::Phylo::Forest') ) {
		$tree = $block->first;
		last BLOCK;
	}
}

# Set the name space of the tree
$tree->set_namespaces( 'pm' => 'http://phylomap.org/terms.owl#' );

# Pass in the tree object
$drawer->set_tree($tree);

# Compute the coordinates
$drawer->compute_coordinates;


# Open the metadata file and parse the contents
open(INPUT, "<:utf8", "$datafile") || die "Cannot open $datafile!: $!";
	while (my $in = <INPUT>) {
		# Skip the first line
		next if ($. == 1);
		chomp($in);
		
		# Grab the TSV values
		my ($left_name, $right_name, $image, $content, $link, $hovertext, $zoomlevels) = split(/\t/,$in);
		
		my $left_node  = $tree->get_by_name( $left_name );
		my $right_node  = $tree->get_by_name( $right_name );
		my $mrca = $left_node->get_mrca( $right_node );
		
		$mrca->set_meta_object( "pm:image" => "$image" ) unless !defined($image);
		$mrca->set_meta_object( "pm:content" => "$content" ) unless !defined($content);
		$mrca->set_meta_object( "pm:link" => "$link" ) unless !defined($link);
		$mrca->set_meta_object( "pm:hovertext" => "$hovertext" ) unless !defined($hovertext);
		# Remove the quotes
		$zoomlevels =~ s/"//g;
		$mrca->set_meta_object( "pm:zoom" => "$zoomlevels" ) unless !defined($zoomlevels);

		
}

# Set the location of the files
my $location = $config->{destination}.'/';
# Create the directory if it does not exist
if (! -d $location) {
	mkpath($location, 0, 0755) || die "Cannot create directory!: $!";
}

saveImageSVG($drawer->draw, $location,  $config->{size}->{tree});


# This we just do to create properly nested NeXML
my $proj = $fac->create_project;
my $forest = $fac->create_forest;
$forest->insert($tree);
$proj->insert($forest);


# Output the NeXML file
open(OUTPUT, ">:utf8", $location."tree.xml") || die "Cannot open tree.xml!: $!";
	print OUTPUT $proj->to_xml;
close(OUTPUT);

# Go through all of the meta data and add it to an array
my @meta;
foreach my $tree ( @{ $forest->get_entities } ) {

    print ref $tree;

    foreach my $node ( @{ $tree->get_entities } ) {
		if (defined $node->get_meta_object('pm:content')) {
			# Set the zoom levels to be an array 
			my @zoom = split(",", $node->get_meta_object('pm:zoom'));
			
     		push(@meta, {
     			'x' => $node->get_x, 
     			'y' => $node->get_y, 
     			'image'	=> $node->get_meta_object('pm:image'),  
     			'content' => $node->get_meta_object('pm:content'), 
     			'link' => $node->get_meta_object('pm:link'),
     			'hovertext' => $node->get_meta_object('pm:hovertext'),
     			'zoom' => \@zoom
     		});
		}
     }
 }
 
 # Convert the array to JSON data so that it can be parsed by Javascript
 my $nodehash = {};
 $nodehash->{markers} = \@meta;
 my $json = JSON->new->encode($nodehash);

# Open the template file, replace values and save it as a new file 
open (INPUT, "files/template.html") or die("Unable to open template file");
open(OUTPUT, ">:utf8", $location."treeviewer.html") || die "Cannot create treeviewerfile!: $!";
while(<INPUT>) {
    if(/REPLACE_TREESIZE/) {
        s/REPLACE_TREESIZE/$config->{size}->{tree}/ges;   
    }
    if(/REPLACE_WINDOWSIZE/) {
        s/REPLACE_WINDOWSIZE/$config->{size}->{window}/ges;   
    }
    if(/REPLACE_MARKERS/) {
        s/REPLACE_MARKERS/$json/; 
    }
    if(/REPLACE_MAXZOOM/) {
        s/REPLACE_MAXZOOM/$tilelevel/; 
    }
    if(/REPLACE_MINZOOM/) {
        s/REPLACE_MINZOOM/$config->{size}->{zoom}->{minimum}/; 
    }
    print OUTPUT $_; 
}

# Copy over the Javascript files
copy("files/phylotiler.js", $location."phylotiler.js") or die "Copy failed: $!";
copy("files/markerwithlabel.js", $location."markerwithlabel.js") or die "Copy failed: $!";

close(INPUT);

sub saveImageSVG {
	my ($drawer, $location, $size) = @_;
	
	open(OUTPUT, ">:utf8", $location."tree.svg") || die "Cannot open tree.svg!: $!";
		print OUTPUT $drawer;
	close(OUTPUT);
	
	my $inkscape = 'inkscape';
	
	# If using a Mac then you need to point to the exact location of the command
	if ($Config{osname} eq 'darwin') {
		$inkscape = '/Applications/Inkscape.app/Contents/Resources/bin/inkscape';
	}
	# Runthe command to convert the SVG to a PNG
	system($inkscape.' -z -f'. $location.'tree.svg -w '. $size .' -h'. $size .' -e'. $location.'tree.png');
 	
 	my $img = Image::Magick->new(magick=>'jpg');
	
	$img->ReadImage( $location.'tree.png');
	$img->Write($location."tree.jpg"); 
	undef $img;
  	saveImageThumbnailTile($location.'tree.jpg');
	
}

sub saveImageThumbnailTile {
	my ($image) = @_;

    my $tile_dir = $location.'tiles';
    $tile_dir =~ s/\.\w+$//;
	
	
	#my $img = Image::Magick->new(magick=>'jpg');
	#$img->BlobToImage( $svg );

	#$img->Resize(geometry=>'800x800');
	#$img->Write($location."tree.jpg");
	my $img = Image::Magick->new(magick=>'jpg');
	
	$img->Read($image);	
	
    my $w   = $img->Get('width');
    my $h   = $img->Get('height');

    # (Re)create the target directory
    my $ubak = umask(0);
    mkpath($tile_dir, 0, 0755);
    umask($ubak);
    # Find the next largest multiple of 256 and the power of 2
    my $dim = ($w > $h ? $w : $h);
    my $pow = -1;
    for (;;) {
       $pow++;
       my $i = 256 * (2 ** $pow);
       next if ($i < $dim);
       $dim = $i;
       last;
    }
    # Resize the source image up to the larger size, so the zoomed-out images
    # get as little of the black padding/background as possible.  Hopefully it
    # won't distort the images too badly.
    if ($dim > $w && $dim > $h) {
     # Determine the optimal pixel radius for sharpening, and do so
		my $sharp = ($w / $dim > $h / $dim
        	? $dim / $w
            : $dim / $h
         ) / 2;
        $img->Sharpen(radius => $sharp);
        # Resize
        $img->Resize(geometry => "${dim}x$dim");
    }
    # Build a new square image with a black background, and composite the
    # source image on top of it.
	my $master = Image::Magick->new;
    $master->Set('size' => "${dim}x$dim");
    $master->Read("xc:black");
    $master->Composite(
    	'image'   => $img,
        'gravity' => 'Center',
    );
    # Cleanup
    undef $img;
    # Create slice layers
    my $layer = 0;
	for (;;) {
    	# Google Maps only allows 19 layers (though I doubt we'll ever
        # reach this point). 
        last if ($layer >= $config->{size}->{zoom}->{maximum});
		
		my $width = 256 * (2 ** $layer);
        last if ($width > $dim);

		mkdir("$tile_dir/$layer", 0775) unless (-d "$tile_dir/$layer");

		my $crop_master = $master->Clone();
        $crop_master->Blur(radius => ($dim / $width) / 2);
        $crop_master->Resize(
        	geometry => "${width}x$width",
            blur     => .7,
		);
        my $max_loop = int($width / 256) - 1;

		foreach my $x (0 .. $max_loop) {
        	foreach my $y (0 .. $max_loop) {
            	my $crop = $crop_master->Clone();
                $crop->Crop(
                	height => 256,
                    width  => 256,
                    x      => $x * 256,
                    y      => $y * 256,
                 );
                 $crop->Write(
                 	filename => "$tile_dir/$layer/$x-$y.jpg",
                    quality  => 75,
                 );
                 $ubak = umask(0);
                 chmod 0644, "$tile_dir/$layer/$x-$y.jpg";
                 umask($ubak);
                 undef $crop;
				}
            }
		$layer++;
        # Cleanup
            undef $crop_master;
       	}
       	 $tilelevel = $layer-1;
   		# Cleanup
        undef $master;

}
