PhyloTiler
==========


## Requirements
<ul>
 <li>You must have Perl installed</li>
 <li> You must have Inkscape installed</li>
 <li>You must have VIPS installed</li>
 <li>The following CPAN modules need to be installed:</li>
 <ul>
  <li>Bio::Phylo</li>
  <li> XML::Simple</li>
  <li> Image::Size</li>
  <li>File::Path</li>
  <li> File::Copy</li>
  <li> File::Copy::Recursive</li>
  <li>Config</li>
  <li>JSON</li>
 </ul>
</ul>


##Installation
You must install the following to run the program:
	Perl - http://www.perl.org/
	Inkscape - http://www.inkscape.org/
	VIPS - http://www.vips.ecs.soton.ac.uk/


## OS X Specific Installation Issues
To install Inkscape, download XQuartz and install it (http://xquartz.macosforge.org/landing/) and then download and install Inkscape (http://inkscape.org/download/).

<ol>
<li>Install libffi:<br />
 ftp://sourceware.org/pub/libffi/libffi-3.0.13.tar.gz</li>
<li>Install gettext:</li>
http://ftp.gnu.org/pub/gnu/gettext/gettext-0.18.3.2.tar.gz</li>
<li>Intall glib:</li>

 * ``` curl http://ftp.gnome.org/pub/gnome/sources/glib/2.31/glib-2.31.14.tar.xz -o glib.tgz```


 * ```tar zxf glib.tgz ```

<li>Before running ./configure, apply the following patch: </li>
 edit glib/glib/gconvert.c line 61:

 * \#if defined(USE_LIBICONV_GNU) && !defined (_LIBICONV_H) <br />
  /* #error GNU libiconv in use but included iconv.h not from libiconv \*/ <br />
 \#endif <br />
 \#if !defined(USE_LIBICONV_GNU) && defined (_LIBICONV_H) <br />
  /\* #error GNU libiconv not in use but included iconv.h is from libiconv */ <br />
\#endif

<li> Install vips:</li>
http://www.vips.ecs.soton.ac.uk/supported/current/vips-7.38.5.tar.gz
</ol>

## Windows Specific Installation Issues
Once Inkscape and VIPS are installed, make sure to set their install directories in your PATH environment variable.


## Running the Script
You can run the script from the command line.  The script takes two parameters.  The first is the location of the Tree file.  The second is the location of the 
metadata file.  An example is phylo.pl Tree.tre metadata.txt.  To run the examples included in the files: phylo.pl example/Viburnum.tre example/info.txt

## Configuration
The configuration is read from an XML file, config.xml.  The following is available to configure:
<ul>
 <li>Zoom - Minimum: The minimum zoom for the Google Maps tile viewer.  Default: 1</li>
<li>Zoom - Maximum: The maximum zoom for the Google Maps tile viewer.  This will determine the image size and how many levels to tile the image. Default: 5</li>
<li> Shape: The shape of the tree. Default: RECT. Available modes: RECT,DIAG,CURVY,RADIAL</li>
<li>Destination: The file location where you would like the package files to go.  Default: package (same folder as source files)</li>
</ul>

There is a metadata template file, template.txt, which can be used to add metadata records.  You can open template.txt with Excel.  The bigger the size of the tree, the better details you will get.

The metadata file contains the following fields:
<ul>
<li>LEFT NAME - Left name.</li>
<li>RIGHT NAME - Right name.</li>
<li> IMAGE - An image for the popup window when the point in the tree is clicked.</li>
<li>CONTENT - The text for the popup window when the point in the tree is clicked.</li>
<li> LINK - A clickable link for the popup window when the point in the tree is clicked.</li>
<li>HOVER TEXT - Text that will appear next to the point.</li>
<li>ZOOM LEVELS - You can set the zoom level of the Google Map at which the point will appear or not appear. The format should use a comma to separate the numbers, eg. 2,3,5  If nothing is set, it will show on all levels.</li>
</ul>

Please note that when a bigger tree is being generated, it may take longer for the script complete.


## License
Released under the [GNU GENERAL PUBLIC LICENSE](http://opensource.org/licenses/GPL-3.0).
