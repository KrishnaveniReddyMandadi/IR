use strict;
use LWP::UserAgent;
use HTML::FormatText;
use CAM::PDF;
use Lingua::Stem::En;

my @file_links;
my @old_links;
my @new_links;


####This part downloads the data to text files in local. Can be ignored if already downloaded.
sub get_text {
        ####To get test from URL
        my $url=$_[0];
                my $content = "";
                if ( $url =~ m/.pdf$/ ){
                        #my $resp = LWP::Simple("$url",'sample.pdf');
                        `curl -s $url -o sample.pdf`;
                        my $pdfone = CAM::PDF->new('sample.pdf');
                        #       my $content=$pdf->toString();
			if (not defined $pdfone) {
				return "";
				#$content = "Error: Cannot Open/Read PDF present at $url. Skipping";
			}
			else {
                        	for my $page (1 .. $pdfone->numPages()) {
                                	my $text = $pdfone->getPageText($page);
                                	$content = $content . $text ; 
				}
			}
                }
                elsif ($url =~ m/http.*/) {
                        $content =`curl -s $url`;
                }
        #From FormatText sample in the module
        my $string = HTML::FormatText->format_string(
        $content,
        leftmargin => 0, rightmargin => 50
        );
        return $string;
}

sub get_all_text {
        ####To get text from URL
        my $url=$_[0];
        #From LWP tutorial
        my $ua = new LWP::UserAgent;
        $ua->timeout(120);
        my $request = new HTTP::Request('GET', $url);
        my $response = $ua->request($request);
        my $content = $response->content();
        return $content ;
}

sub get_links{
        my $lnk=$_[0];
        #$lnk= s/\?.*$//g;
        if ( $lnk =~ m/\?/ ) {
                $lnk= substr ($lnk ,0, index($lnk,'?'));
        }
        my @content = split(/\n/, `curl -s  $lnk`);
        my @links = grep(/<a.*href=.*>/,@content);
        my $link;
        foreach my $c (@links){
        #source https://stackoverflow.com/questions/254345/how-can-i-extract-url-and-link-text-from-html-in-perl
                $c =~ /<a.*href="([\s\S]+?)".*>/;
                $link = $1;
                $link =~ s/#.*//;
                next if $link eq "";
		next if $link eq "https://browsehappy.com/";
                if ( ($link =~ m/.txt$/ || $link =~ m/.html$/ || $link =~ m/.pdf$/ || $link =~ m/.php$/ || $link =~ m/.aspx$/) ) {
                        if ($link =~ m/^(?!http)/ ){
                                $link = $lnk . "/" . $link;
                        }
                                #printf "File found $link \n";
                                push(@file_links, $link) unless grep{$_ eq $link} @file_links;
                }
                else{
                                next if grep{$_ eq $link} @old_links;
                                push(@new_links, $link) unless grep{$_ eq $link} @new_links;
                                #  print "New Link found: $link \n";
                }
  }
}

####Requesting for keywords:
#print "Please provide the search keywords?\n";
#my $input= <>;
#chomp ($input);
#print FH "Query words : $input\n";

#my $prv_lnk=$ARGV[0];
my $prv_lnk="https://www.memphis.edu/";
#printf "Link provided : $prv_lnk \n";

print "Downloading files....";

get_links($prv_lnk);
if (scalar @new_links == 0 ){
        print "Provided link does not have any child links."
}

do {{
 # get the next array element
 my $link = shift(@new_links);
 push(@old_links, $link);
 get_links($link);
}}until(!scalar @new_links > 0 || scalar @file_links >2000);

#print "File Links @file_links \n";

my $file_cnt=1;
my %file_uri;

####Looping though child links
foreach my $file_lnk (@file_links){
	#next if $file_cnt > 5000;
        my $txtfile="Doc_".$file_cnt.".txt";
        my $file_text = get_text($file_lnk);
	next if $file_text eq "";
	$file_uri{$txtfile}="${file_lnk}";
        open (FH, '>' , $txtfile) or die $!;
	#printf FH "Document Link : $file_lnk\n";
	#printf FH "\n";
        print FH "$file_text \n";
        close (FH);
$file_cnt++
}


print "\nDone\n";
print "Reading Files\n";
#####Reading downloaded files to hashes

my @files = glob( '*.txt' );
my @stop_words=split(/\n/, `curl -s  https://cs.memphis.edu/~vrus/teaching/ir-websearch/papers/english.stopwords.txt`);

sub cleanup_line{
        #print "Line : @_ \n";
        my @words_init = split(' ', $_[0]);
        my %count;
        foreach my $word (@words_init){
                my $lc_word = lc($word);
                next if ( grep( /^\Q$lc_word\E$/, @stop_words ) ); ##Check for stop words
                next if ($word =~ /^(?:(?:http?|s?ftp))/i);  ##Check for url
                next if ($word =~ /[<>]/);  ##Check for html contents - Mostly looking for < and >
                next if ($word =~ /[A-Z]/); ##Remove words having upper case
                $word =~ s/[0-9]//g;   ##Remove digits
                $word =~ s/[[:punct:]]//g;  ##Remove punctuations
                next if ( $word eq "" );
                ####Use of Porter Stemmers logic to remove morphological variations
                my $stemword=Lingua::Stem::En::stem( {-words => [$word] });
                my $finword=@$stemword[0];
                $count{$finword}++;
        }
        return %count;
}

sub preprocess_file{
        my $file=$_[0];
        open my $handle, '<', $file;
        my %file_words;
        (my @lines = <$handle>);
        close $handle;
        foreach my $line (@lines){
                #print "Line : $line \n";
                my %line_wrds=cleanup_line($line);
                #print Dumper %line_wrds;
                foreach my $str (keys %line_wrds){
                        $file_words{$str}=$file_words{$str}+$line_wrds{$str}
                }
        }
	unlink ($file);
        return %file_words;
}

open(FH, '>', "wrd_wt.csv" ) or die $!;

my %dict;
my @processed_file;
my $pf_cnt=0;
my %fileeulgt;###euclidean lenght of file
my %wordwt; ###term vector in each file
foreach my $file (@files){
        if ($file =~ m/.txt$/){
                $pf_cnt++;
		my $wrd_cnt=0;
		#print FH "Doc_$pf_cnt = $file\n";
                my %words_in_file=preprocess_file($file);
                #print Dumper %words_in_file;
                foreach my $wrd (keys %words_in_file) {
                        $dict{$wrd}{$file}=$words_in_file{$wrd};
			$wrd_cnt= $wrd_cnt + ($words_in_file{$wrd} * $words_in_file{$wrd});
                }
		$wrd_cnt=sqrt($wrd_cnt);
		$fileeulgt{$file}=$wrd_cnt;
                push (@processed_file, $file);
        }
}

my $file_cnt=0;
open(FH1,'>',"file_map.csv") or die $!;
print FH "Word";
foreach my $p_file (@processed_file) {
        $file_cnt++;
	print FH1 "Doc_${file_cnt}.txt,$file_uri{$p_file},$fileeulgt{$p_file}\n";
	print FH ",Doc_${file_cnt}.txt";
        #print FH "Doc_${file_cnt}  | ";
	#print "file : $p_file : $file_uri{$p_file} \n";
        foreach my $wrd1 (keys %dict){
		#		if (exists $dict{$wrd1}{$p_file}){
		#	$wordwt{$wrd1}{$p_file}= $dict{$wrd1}{$p_file} / $fileeulgt{$p_file};
		#	next
		#}
                next if (exists $dict{$wrd1}{$p_file});
                $dict{$wrd1}{$p_file}=0;
		$wordwt{$wrd1}{$p_file}=0;
        }
}
print FH "\n";

my @doc_wrds;
foreach my $wrd2 (sort keys %dict){
	push (@doc_wrds,$wrd2)
}

foreach my $wrd3 (@doc_wrds){
	print FH "$wrd3";
	foreach my $p_file (@processed_file) {
		print FH ",$dict{$wrd3}{$p_file}";
	}
	print FH "\n";
}
close(FH1);
close(FH);

