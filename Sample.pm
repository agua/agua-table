package Table::Sample;
use Moose::Role;
use Method::Signatures::Simple;

=head2

	PACKAGE		Table::Sample
	
	PURPOSE
	
		sample TABLE METHODS
		
=cut

method loadSamples ($username, $projectname, $table, $sqlfile, $tsvfile) {
	$username	=	$self->username() if not defined $username;
	$projectname	=	$self->projectname() if not defined $projectname;
	$table		=	$self->table() if not defined $table;
	$sqlfile		=	$self->sqlfile() if not defined $sqlfile;
	$tsvfile		=	$self->tsvfile() if not defined $tsvfile;
	
	$self->logError("username not defined") and return if not defined $username;
	$self->logError("projectname not defined") and return if not defined $projectname;
	$self->logError("table not defined") and return if not defined $table;
	$self->logError("sqlfile not defined") and return if not defined $sqlfile;
	$self->logError("tsvfile not defined") and return if not defined $tsvfile;

	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("table", $table);
	$self->logDebug("sqlfile", $sqlfile);
	$self->logDebug("tsvfile", $tsvfile);
	
	$self->logError("Can't find sqlfile: $sqlfile") and return if not -f $sqlfile;
	$self->logError("Can't find tsvfile: $tsvfile") and return if not -f $tsvfile;

	#### SET DATABASE HANDLE	
	$self->setDbh() if not defined $self->db();
	return if not defined $self->db();

	#### LOAD SQL
	my $query	=	$self->fileContents($sqlfile);
	$self->logDebug("query", $query);
	$self->db()->do($query);

	#### DELETE FROM TABLE
	$query		=	qq{DELETE FROM $table
WHERE projectname='$projectname'
AND username='$username'};
	$self->logDebug("query", $query);
	$self->db()->do($query);
	
	#### CREATE TSV
	my $tempfile	=	$self->createTempTsvFile($username, $projectname, $tsvfile);

	#### LOAD TSV
	my $success	=	$self->loadTsvFile($table, $tempfile);
	$self->logDebug("success", $success);

	#### CLEAN UP
	`rm -fr $tempfile`;
	
	#### ADD ENTRY TO sampletable TABLE
	if ( $self->db()->hasTable($table) ) {
		$query	=	qq{SELECT 1 FROM sampletable
WHERE username='$username'
AND projectname='$projectname'
AND sampletable='$table'};
		$self->logDebug("query", $query);
		my $exists = $self->db()->query($query);
		$self->logDebug("exists", $exists);
		
		return if $exists;
    }

	$query	=	qq{INSERT INTO sampletable VALUES
	('$username', '$projectname', '$table')};
	$self->logDebug("query", $query);
	$success	=	$self->db()->do($query);
	$self->logDebug("success", $success);

    	
	return $success;	
}

method createTempTsvFile ($username, $projectname, $tsvfile) {
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("tsvfile", $tsvfile);
	
	my $lines		=	$self->getLines($tsvfile);
	my $tempfile	=	"$tsvfile.temp";
	my $outputs	=	[];
	foreach my $line ( @$lines ) {
		next if $line =~ /^\s*sample\s+/;
		next if $line =~ /^#/;
		push @$outputs,	"$username\t$projectname\t$line";
	}
	
	open(OUT, ">", $tempfile) or die "Can't open tempfile: $tempfile\n";
	foreach my $output ( @$outputs ) {
		print OUT $output;
	}
	close(OUT) or die "Can't close tempfile: $tempfile\n";

	return $tempfile;
}

method loadSampleFiles ($username, $projectname, $workflowname, $workflownumber, $file) {
	my $table	=	"samplefile";
	$username	=	$self->username() if not defined $username;
	$projectname	=	$self->projectname() if not defined $projectname;
	$workflowname	=	$self->workflowname() if not defined $workflowname;
	$workflownumber	=	$self->workflownumber() if not defined $workflownumber;
	
	$self->logError("username not defined") and return if not defined $username;
	$self->logError("projectname not defined") and return if not defined $projectname;
	$self->logError("workflowname not defined") and return if not defined $workflowname;
	$self->logError("workflownumber not defined") and return if not defined $workflownumber;
	$self->logDebug("username", $username);
	$self->logDebug("projectname", $projectname);
	$self->logDebug("workflowname", $workflowname);
	$self->logDebug("workflownumber", $workflownumber);
	$self->logDebug("table", $table);
	$self->logDebug("file", $file);
	
	$self->logError("Can't find file: $file") and return if not -f $file;

	my $lines	=	$self->fileLines($file);
	$self->logDebug("no. lines", scalar(@$lines));

	#### SET DATABASE HANDLE	
	$self->setDbh() if not defined $self->db();
	return if not defined $self->db();

	my $tsv = [];
	foreach my $line ( @$lines ) {
		my ($sample, $filename, $filesize)	=	$line	=~ 	/^(\S+)\s+(\S+)\s+(\S+)/;
		#$self->logDebug("sample", $sample);
		
		my $out	=	"$username\t$projectname\t$workflowname\t$workflownumber\t$sample\t$filename\t$filesize";
		push @$tsv, $out;
	}
	
	my $outputfile	=	$file;
	$outputfile		=~	s/\.{2,3}$//;
	$outputfile		.=	"-$table.tsv";
	my $output	=	join "\n", @$tsv;
	$self->logDebug("output", $output);

	$self->printToFile($outputfile, $output);
	
	my $success	=	$self->loadTsvFile($table, $outputfile);
	$self->logDebug("success", $success);
	
	return $success;	
}


# method fileLines ($file) {
# #### GET THE LINES FROM A FILE
# 	my $contents = $self->fileContents($file); 
# 	return if not defined $contents;

# 	my @lines = split "\n", $contents;

# 	return \@lines;
# }

# method fileContents ($file) {
#     $self->logDebug("file", $file);
#     die("file not defined\n") if not defined $file;
#     die("Can't find file: $file\n$!") if not -f $file;

#     my $temp = $/;
#     $/ = undef;
#     open(FILE, $file) or die("Can't open file: $file\n$!");
#     my $contents = <FILE>;
#     close(FILE);
#     $/ = $temp;
    
#     return $contents;
# }

method loadTsvFile ($table, $file) {
	$self->logCaller("");
	return if not $self->can('db');
	
	$self->logDebug("table", $table);
	$self->logDebug("file", $file);
	
	$self->setDbh() if not defined $self->db();
	return if not defined $self->db();

	#### DON'T USE 'LOAD DATA LOCAL INFILE' (MYSQL ONLY)
	my $success = $self->db()->importFile($table, $file);
	$self->logCritical("load data failed") if not $success;
	
	return $success;	
}



1;