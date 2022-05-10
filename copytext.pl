#Perl script that copies, line by line, a text file into a destination file
use warnings;
use strict;
#below are source and target files created at documnets folder
my $srcfile  = 'C:\Users\Admin\Documents\source.txt';
my $targetfile = 'C:\Users\Admin\Documents\target.txt';
#opening and reading the src file
open my $src, '<', $srcfile    or die "$srcfile: $!";
#opening and writing mode of  target file
open my $tar, '>', $targetfile or die "$targetfile: $!";
#print the line by line to target folder until while loop done
while (<$src>) {
   print $tar $_;
}
#close the source file
close $src;
#close the target file
close $tar;
