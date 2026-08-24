#!/usr/bin/perl

# This tool scans all the entries in the phocadownloads database to disable
# entries with no physical file

use strict;
use warnings;
use DBI;
use DBD::mysql;


# No changes below here
my $CurTitle="";
my $CurAlias="";
my $CurPublished="";
my $CurFilename="";
my $CurId=0;
my $timeout=5;
my $VERSION="1.0.0";
my $DB_Owner="";
my $DB_Pswd="";
my $DB_Name="";
my $DB_Prefix="";
my $DB_Table="";
my $DownloadDir = "/var/www/html/jdownloads";
my $dbh;
my $CONF_FILE="$ENV{HOME}/.disable_missing.txt";
my $CurNotify="";
my $CurName="";
my $email="";
my $IconDir="/var/www/html/images/jdownloads/fileimages/flat_1/";
my $UnknownType = "unknown";
my $FILEEDITOR = $ENV{EDITOR};

if (! defined($FILEEDITOR))
{
        $FILEEDITOR = "vi";
}
elsif ($FILEEDITOR eq "")
{
        $FILEEDITOR = "vi";
}

# Get if they said a option
my $CMDOPTION = shift;

# Read in configuration options
if (! -f $CONF_FILE)
{
	my $DefaultConf = <<"END_MESSAGE";
DB_User	joomla
DB_Pswd	foobar
DB_DBName	joomla
DB_DBtblpfx	zzz_
DOWNLOAD_DIR	$DownloadDir
END_MESSAGE
	open (my $FH, ">", $CONF_FILE) or die "Could not create config file '$CONF_FILE' $!";
        print $FH "$DefaultConf\n";
	close($FH);
	system("$FILEEDITOR $CONF_FILE");
	exit 0;
}

open(CONF, "<$CONF_FILE") || die("Unable to read config file '$CONF_FILE'");
while(<CONF>)
{
	chop;
	if ($_ eq "")
	{
		next;
	}
	my ($FIELD_TYPE, $FIELD_VALUE) = split (/	/, $_);
	#print("Type is $FIELD_TYPE\n");
	if (! defined($FIELD_TYPE))
	{
		# Field type not defined
		print "Field type not defined for '$_'\n";
		next;
	}
	if ($FIELD_TYPE eq "DB_User")
	{
		$DB_Owner = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DB_Pswd")
	{
		$DB_Pswd = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DB_DBName")
	{
		$DB_Name = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DB_DBtblpfx")
	{
		$DB_Prefix = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DOWNLOAD_DIR")
	{
		$DownloadDir = $FIELD_VALUE;
	}
}
close(CONF);

# Check if the file exists
sub CheckExists
{
	if (-f "$DownloadDir/$CurFilename")
	{
		# This file exists
		# print "File $CurFilename exists\n";
		return;
	}
	if ($CurPublished == 0)
	{
		print "File $CurTitle already disabled\n";
		return;
	}
	# File doesn't exist
	print "File $CurTitle doesn't exist - setting to disabled\n";
	$CurPublished = 0;
	$dbh->do("UPDATE $DB_Table SET published = ? WHERE id = ?",
		undef,
		$CurPublished,
		$CurId);
}

print("disable missing files ($VERSION)\n");
print("===========================================\n");

if (defined $CMDOPTION)
{
        if ($CMDOPTION ne "prefs")
        {
                print "Unknown command line option: '$CMDOPTION'\nOnly allowed option is 'prefs'\n";
                exit 0;
        }
	system("$FILEEDITOR $CONF_FILE");
	exit 0;
}

### The database handle
$dbh = DBI->connect ("DBI:mysql:database=$DB_Name:host=localhost",
                           $DB_Owner,
                           $DB_Pswd) 
                           or die "Can't connect to database: $DBI::errstr\n";

$DB_Table = $DB_Prefix . "phocadownload";

### The statement handle
my $sth = $dbh->prepare("SELECT id, title, alias, filename, published FROM $DB_Table");

$sth->execute or die $dbh->errstr;

my $rows_found = $sth->rows;

while (my $row = $sth->fetchrow_hashref)
{
	$CurId = $row->{'id'};
	$CurTitle = $row->{'title'};
	$CurAlias = $row->{'alias'};
	$CurFilename = $row->{'filename'};
	$CurPublished = $row->{'published'};
	#print "Saw $CurTitle\n";
	if ($CurFilename ne "")
	{
		CheckExists();
	}
}
exit(0);
