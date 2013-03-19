PhyloTiler
==========

## Requirements
* You must have Perl installed.
* You must have ImageMagick with PerlMagick installed
* The following CPAN modules need to be installed
** XML::Simple
** Image::Magick
** File::Path
** JSON

## Running the Script
You can run the script from the command line.  The script takes two parameters.  The first is the location of the Tree file.  The second is the location of the 
metadata file.  An example is phylo.pl Tree.tre metadata.txt

## Configuration
The configuration is read from an XML file, config.xml.  The following is available to configure
* Size - Tree: The pixel size of the tree on the page.  This number should be a factor of 256 for the Google tiles.  Default: 1024
* Size - Window: The size of the Google Maps window containing the tile. Default: 512
* Zoom - Minimum: The minimum zoom for the Google Maps tile viewer.  Default: 1
* Zoom - Maximum: The maximum zoom for the Google Maps tile viewer.  This will determine how many levels to tile the image.  The tiler will stop before if the image is too small to tile anymore levels.  Default: 4
* Shape: The shape of the tree. Default: RECT. Available modes: RECT,DIAG,CURVY,RADIAL
* Destination: The file location where you would like the package files to go.  Default: package (same folder as source files)
There is a metadta template file, template.txt, which can be used to add metadata records.

## License
Released under the [MIT license](http://www.opensource.org/licenses/MIT).