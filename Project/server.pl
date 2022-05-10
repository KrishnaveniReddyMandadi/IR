#!/usr/bin/perl
use warnings; use strict;
use HTTP::Server::Simple::CGI;


{
	package WebServer; use base 'HTTP::Server::Simple::CGI';
sub get_match {
	my $search_str=shift;
	######Query vector
	my @qry_str1=split(' ',$search_str);
	#####Removing dupes
	my %seen = ();
	my @qry_str = grep { ! $seen{ $_ }++ } @qry_str1;
	#####
	my $qry_wrd_cnt=scalar(@qry_str);
	my %qry_wrd_wt;
	foreach my $qry_wrd (@qry_str){
		$qry_wrd_wt{$qry_wrd}= 1 / sqrt($qry_wrd_cnt);
	}
	#########Calculating cosines
	my @unmtchd_wrds;
	my %cosqd;
	foreach my $p_file (@main::processed_file) {
		$cosqd{$p_file}=0;
		next if $main::fileeulgt{$p_file}==0;
		foreach my $qry_wrd (@qry_str){
			if(not grep( /^\Q$qry_wrd\E$/, @main::doc_wrds ) ) {
				push(@unmtchd_wrds, $qry_wrd) unless grep{$_ eq $qry_wrd} @unmtchd_wrds;
				next;
			}
			$cosqd{$p_file}=($qry_wrd_wt{$qry_wrd}*$main::dict{$qry_wrd}{$p_file}/$main::fileeulgt{$p_file}) + $cosqd{$p_file};
		}
	}
	return %cosqd;
}

sub handle_request { # {{{

    my $self = shift;
    my $cgi  = shift;
	print "HTTP/1.0 200 OK\r\n", $cgi->header, $cgi->start_html("Document search");

	    print $cgi->start_form(),
	       "<p align=\"left\"> Words to query : ",
	       $cgi->textfield('search_string'),
	       $cgi->submit(-value => 'Search'), $cgi->end_form(),
	       "<br><i>(space delimited values, search is case-insensitive)</i><p>";
	    print "<hr>";
   	    my $search_string = $cgi->param('search_string');
	    if ($search_string) {	# Display search results
	    	print $cgi->h1("Notes that match \"$search_string\"");
			my %cosqd;
			my @unmtch_wrds;
			%cosqd=get_match($search_string);
			print "File Link  | Cosine word wt <br>";
			foreach my $file (sort {$cosqd{$b} <=> $cosqd{$a}} (keys %cosqd) ){
				if ($cosqd{$file}!=0) {
				print "$main::file_uri{$file} | $cosqd{$file} <br>";
				}
			}
			#print "Unmatched Words : @unmtch_wrds <br>";
		
	    }
		print $cgi->end_html;

      return;

} # }}}


}

our @processed_file;
our %dict;
our %fileeulgt;###euclidean lenght of file
our %file_uri;
our @doc_wrds;

#####Loading file data
open(my $data, '<', "./wrd_wt.csv") or die $!;
my $line_num=0;
while (my $line = <$data>){
	chomp($line);
	my @words = split ",", $line;
	if ($line_num==0){
		@processed_file=@words;
		splice @processed_file, 0, 1;
	}
	else{
		my $lc_word=lc($words[0]);
		next if $lc_word eq "";
		my $file_cnt=0;
		foreach my $file (@processed_file){
			$file_cnt++;
			$dict{$lc_word}{$file}=int($words[$file_cnt]);
		}
		push(@doc_wrds,$lc_word);
	}
	$line_num++;
}
open(my $data1,'<',"file_map.csv") or die $!;
my $line_num1=1;
while (my $line1 = <$data1>) {
	chomp ($line1);
	my @file_dtl = split ",", $line1;
	$fileeulgt{$file_dtl[0]}=$file_dtl[2];
	$file_uri{$file_dtl[0]}=$file_dtl[1];
}



# Use Port 8080 (http://localhost:8081)
my $pid = WebServer -> new(8081) -> background;
print "pid of webserver=$pid\n";

