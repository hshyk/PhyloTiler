#!/bin/sh
set -e

function download() {
  url=$1
  base=$(basename $1)

  if [[ ! -e $base ]]; then
    echo "curling $url"
    curl -O -L $url
  fi
}

mkdir magick-installer
cd magick-installer

# As of OSX 10.8, libtool needs to be installed
download http://ftpmirror.gnu.org/libtool/libtool-2.4.tar.gz

download http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
download http://nongnu.askapache.com/freetype/freetype-2.4.11.tar.gz
download http://sourceforge.net/projects/libpng/files/libpng15/older-releases/1.5.10/libpng-1.5.10.tar.gz
download http://www.imagemagick.org/download/delegates/jpegsrc.v9.tar.gz
download http://download.osgeo.org/libtiff/tiff-3.9.4.tar.gz
download http://heanet.dl.sourceforge.net/project/wvware/libwmf/0.2.8.4/libwmf-0.2.8.4.tar.gz
download http://downloads.sourceforge.net/project/lcms/lcms/1.19/lcms-1.19.tar.gz
download http://sourceforge.net/projects/ghostscript/files/GPL%20Ghostscript/9.05/ghostscript-9.05.tar.gz
download http://heanet.dl.sourceforge.net/project/gs-fonts/gs-fonts/8.11%20%28base%2035%2C%20GPL%29/ghostscript-fonts-std-8.11.tar.gz
download ftp://ftp.sunet.se/pub/multimedia/graphics/ImageMagick/ImageMagick-6.8.3-4.tar.gz


tar xzf libtool-2.4.tar.gz
cd libtool-2.4
./configure
make clean
make
sudo make install
cd ..


tar xzvf libiconv-1.14.tar.gz
cd libiconv-1.14
cd libcharset
./configure --prefix=/usr/local
make
sudo make install
cd ../..

tar xzvf freetype-2.4.11.tar.gz
cd freetype-2.4.11
./configure --prefix=/usr/local
make clean
make
sudo make install
cd ..

tar xzvf libpng-1.5.10.tar.gz
cd libpng-1.5.10
./configure --prefix=/usr/local
make clean
make
sudo make install
cd ..

tar xzvf jpegsrc.v9.tar.gz
cd jpeg-9
ln -s -f `which glibtool` ./libtool
export MACOSX_DEPLOYMENT_TARGET=10.8
./configure --enable-shared --prefix=/usr/local
make clean
make
sudo make install
cd ..

tar xzvf tiff-3.9.4.tar.gz
cd tiff-3.9.4
./configure --prefix=/usr/local
make clean
make
sudo make install
cd ..

tar xzvf libwmf-0.2.8.4.tar.gz
cd libwmf-0.2.8.4
./configure
make clean
make
sudo make install
cd ..

tar xzvf lcms-1.19.tar.gz
cd lcms-1.19
./configure
make clean
make
sudo make install
cd ..

tar zxvf ghostscript-9.05.tar.gz
cd ghostscript-9.05
./configure  --prefix=/usr/local
make clean
make
sudo make install
cd ..

tar zxvf ghostscript-fonts-std-8.11.tar.gz
sudo mkdir -p /usr/local/share/ghostscript/fonts
sudo mv -f fonts/* /usr/local/share/ghostscript/fonts

tar xzvf ImageMagick-6.8.3-4.tar.gz
cd ImageMagick-6.8.3-4
export CPPFLAGS=-I/usr/local/include
export LDFLAGS=-L/usr/local/lib
./configure --prefix=/usr/local --disable-static --without-fontconfig --with-modules --with-perl --without-magick-plus-plus --with-quantum-depth=8 --with-jpeg=yes --with-jp2=yes --with-png=yes --with-tiff=yes --with-gs-font-dir=/usr/local/share/ghostscript/fonts --disable-openmp
make clean
make
sudo make install
cd ..

cd ..
rm -Rf magick-installer

echo "ImageMagick successfully installed!"

