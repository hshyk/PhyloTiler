#!/usr/bin/perl
use strict;
use warnings;
use Bio::Phylo::Factory;
use Bio::Phylo::Treedrawer;
use Bio::Phylo::IO 'parse_tree';
use Bio::Phylo::IO 'parse';
use XML::Simple;
use Image::Size;
use File::Path;
use File::Copy;
use File::Copy::Recursive 'dirmove';
use File::Copy::Recursive 'pathrmdir';
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

print "Loading the configuration...\n";
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
my $size = 256 * (2 ** $config->{size}->{zoom}->{maximum});


# Instantiate tree drawer
my $drawer = Bio::Phylo::Treedrawer->new(
    '-width'  => $size,
    '-height' => $size,
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

print "Loading datafile... \n";
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

print "Creating destination folder... \n";

# Set the location of the files
my $location = $config->{destination}.'/';
# Create the directory if it does not exist
if (! -d $location) {
	mkpath($location, 0, 0755) || die "Cannot create directory!: $!";
}
print "Saving tree to SVG... \n";
# Create the SVG file
open(OUTPUT, ">:utf8", $location."tree.svg") || die "Cannot open tree.svg!: $!";
	print OUTPUT $drawer->draw;
close(OUTPUT);

print "Saving tree to PNG... \n";
# Convert the original image from SVG to PNG
convertSVGtoImage($location."tree.svg", $location."tree.png",  $size);

print "Tiling the image... \n";
# Tile the tree images
saveImageThumbnailTile($location.'tree.png');

# This we just do to create properly nested NeXML
my $proj = $fac->create_project;
my $forest = $fac->create_forest;
$forest->insert($tree);
$proj->insert($forest);


print "Creating NeXML file... \n";
# Output the NeXML file
open(OUTPUT, ">:utf8", $location."tree.xml") || die "Cannot open tree.xml!: $!";
	print OUTPUT $proj->to_xml;
close(OUTPUT);

print "Creating NEXUS file... \n";
# Output the NEXUS file
open(OUTPUT, ">:utf8", $location."tree.nex") || die "Cannot open tree.nex!: $!";
	print OUTPUT $proj->to_nexus;
close(OUTPUT);

# Go through all of the meta data and add it to an array
print "Attaching metadata... \n";
my @meta;
foreach my $tree ( @{ $forest->get_entities } ) {
	
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

print "Copying files... \n";
# Open the template file, replace values and save it as a new file 
open (INPUT, "files/template.html") or die("Unable to open template file");
open(OUTPUT, ">:utf8", $location."treeviewer.html") || die "Cannot create treeviewerfile!: $!";
while(<INPUT>) {
    if(/REPLACE_TREESIZE/) {
        s/REPLACE_TREESIZE/$size/ges;   
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

print "PhyloTiler Successfully Completed!";


sub convertSVGtoImage {
	my ($svg, $image, $size) = @_;
	
	$size = $size+1;
	my $inkscape = 'inkscape';
	
	# If using a Mac then you need to point to the exact location of the command
	if ($Config{osname} eq 'darwin') {
		$inkscape = '/Applications/Inkscape.app/Contents/Resources/bin/inkscape';
	}
	
	
	# Run the command to convert the SVG to a PNG
	system($inkscape.' -z -f '. $svg.' -w '. $size .' -h '. $size .' -e '. $image) == 0 or die "Inkscape was not able to convert your image";
}

sub saveImageThumbnailTile {
	my ($image) = @_;

    my $tile_dir = $location.'tiles';
    $tile_dir =~ s/\.\w+$//;
	
    (my $w,  my $h) = imgsize($location.'tree.png');

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
    

    my $layer = 0;
	for (;;) {
    	# Google Maps only allows 19 layers (though I doubt we'll ever
        # reach this point). 
        my $width = 256 * (2 ** $layer);
        last if ($layer >= $config->{size}->{zoom}->{maximum} + 1 || $width > $dim || $layer == 19);
		
		print "Tiling level $layer... \n";
		# Create the tile folder
		mkdir("$tile_dir/$layer", 0775) unless (-d "$tile_dir/$layer");
		
      	# Create a png to tile from.  It is created from the SVG for speed reasons over duplicating from ImageMagick
		convertSVGtoImage($location.'tree.svg', $location.'tree_'.$layer.'.png', $width);
		
		# Use the VIPS program to tile the files
		system('vips dzsave '.$location.'tree_'.$layer.'.png '.$location.'tile --depth 1 --tile-size 256 --overlap 0 --suffix .png')  == 0 or die "VIPS is either not installed or unable to process your higher level tile images";
		
		# Move the tiled directory
		dirmove($location.'tile_files/0',$tile_dir.'/'.$layer) or die 'VIPS could not copy your tiles to the correct folder';
		
		pathrmdir($location.'tile_files');
		unlink($location.'tile.dzi');

		# Delete the image which the tiles came from
		unlink($location.'tree_'.$layer.'.png');

		$layer++;
	}
	
    $tilelevel = $layer-1;

}
