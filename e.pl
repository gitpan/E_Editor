#!/perl/bin/perl -s 

#NOTE: Windows compile:  perl2exe -gui -perloptions="-p2x_xbm -s" e.pl
#NOTE: POD compile:  pp -g -M e_static_highlightmodules -o ec.exe e.pl
#NOTE: POD compile:  pp -g -M e_static_basemodules -o e.exe e.pl

#NOTE: In Winblows, you MUST set the palette when starting up rather than 
#relying on the Windows default IF you wish to be able to change the palette 
#later to something that would (using our hacked setPalette routine) be set 
#to a white ("Nite") foreground!!!!  Easiest way 2 do this is to create an 
#"Xdefaults" file in same directory this pgm is in w/ the line:
#tkPalette="#rrggbb"
#You can set this to something very close to Winblows' default background color.

$showgrabopt = '';
$showgrabopt = '-nograb';   #UNCOMMENT IF YOU HAVE MY LATEST VERSION OF JDIALOG!

use lib "/perl/lib";
use lib "/perl/site/lib";
#use lib ".";

########### THIS SECTION NEEDED BY PAR COMPILER! ############
#NOTE:  FOR SOME REASON, v.pl NEEDS BUILDING WITH:  pp -M Tk::ROText ...!
#REASON:  par does NOT pick up USE and REQUIRE's quoted in EVAL strings!!!!!

#
#STRIP OUT INC PATHS USED IN COMPILATION - COMPILER PUTS EVERYTING IN IT'S OWN
#TEMPORARY PATH AND WE DONT WANT THE RUN-TIME PHISHING AROUND THE USER'S LOCAL
#MACHINE FOR (POSSIBLY OLDER) INSTALLED PERL LIBS (IF HE HAS PERL INSTALLED)!
BEGIN
{
	$v = 1  if ($0 =~ /v\w*\./io);
	$vexe = 1  if ($0 =~ /exe$/io);
	if ($vexe)
	{
		while (@INC)
		{
			$_ = shift(@INC);
			push (@myNewINC, $_)  if (/(?:cache|CODE)/o);
		}
		@INC = @myNewINC;
		eval ($0 =~ /[ev]c\w*\./io) ? 'use e_static_highlightmodules'
				: 'use e_static_basemodules';
	}
}
################# END PAR COMPILER SECTION ##################
use File::Copy;
use Tk;                  #LOAD TK STUFF
use Tk ':eventtypes';
use Tk::JDialog;
use Tk::TextUndo;
use Tk::Menubutton;
use Tk::Checkbutton;
use Tk::Radiobutton;
use Tk::ColorEditor;  #ADDED 20010131.
use Tk::Adjuster;
use Tk::NoteBook;
use Text::Tabs;
use Cwd;

eval 'use Tk::DragDrop::Win32Site; use Tk::DropSite qw(Win32); $w32dnd = 1; 1;';
$autoScroll = 0;
eval 'use Tk::Autoscroll; $autoScroll = 1; 1';

eval 'use File::Spec::Win32; 1';
eval 'use File::Glob; 1';
#use Tk::Canvas;
#use Tk::Scale;
use Tk::JOptionmenu;
$haveXML = 0; $haveTextHighlight = 0; $Ansicolor = 0; $SuperText = 0; $havePerlCool = 0;
$haveHTML = 0; $haveJS = 0; $haveBash = 0;

$Steppin = ($ENV{DESKTOP_SESSION} =~ /AfterStep/io) ? 1 : 0;
$bummer = 1  if ($^O =~ /Win/o);

if ($bummer)
{
	$ENV{HOME} ||= $ENV{USERPROFILE}  if (defined $ENV{USERPROFILE});
	$ENV{HOME} ||= $ENV{ALLUSERSPROFILE}  if (defined $ENV{ALLUSERSPROFILE});
	$ENV{HOME} =~ s#\\#\/#gso;
}

#FETCH ANY USER-SPECIFIC OPTIONS FROM e.ini:

$homedir ||= $ENV{HOME} || &cwd();
$homedir .= '/'  unless ($homedir =~ m#\/$#o);
my $curdir = &cwd();
$curdir .= '/'  unless ($curdir =~ m#\/$#o);
$_ = ($0 =~ m#\/([^\/]+)$#o) ? $1 : $0;;
s/(\w+)\.\w+$/$1\.ini/g;
%mimeTypes = ();

while ($curdir) {
print STDERR "-0: trying (${curdir}$_)!\n"  if ($debug);
	last  if (-r "${curdir}$_");
	chop $curdir;
	last  unless ($curdir);
	$curdir =~ s#\/[^\/]+$#\/#o;
}

unless ($curdir)
{
	$_ = $0;
	s/(\w+)\.\w+$/$1\.ini/g;
print STDERR "----2: (look in program dir): ini=$_=\n"  if ($debug);
}

print STDERR "-3: will use (${curdir}$_)!\n"  if ($debug);
if (open PROFILE, "${curdir}$_")
{
	while (<PROFILE>)
	{
		chomp;
		s/[\r\n\s]+$//o;
		s/^\s+//o;
		next  if (/^\#/o);
		($opt, $val) = split(/\=/o, $_, 2);
		if ($opt =~ /^\$/o)
		{
			eval "$opt = \"$val\";";
		}
		else
		{
			${$opt} = $val  if ($opt && !defined(${$opt}));
		}
	}
	close PROFILE;
}

if ($0 =~ /exe$/io)   #FETCH COMMAND-LINE OPTIONS SINCE "-s" DOES NOT WORK IN PAR .exe'S?!
{
	my ($arg, $var, $val);
	while ($#ARGV >= 0 && $ARGV[0] =~ /^\-/o)
	{
		($arg = shift) =~ s/^\-//o;
		($var, $val) = split(/\=/o, $arg);
		$val = 1  unless (length $val);
		eval "\$$var = \"$val\"";
	
	}
}

eval 'use Tk::ROText; 1';
if ($v)
{
	eval 'use Tk::XMLViewer; $haveXML = 1; 1';
	eval 'use Tk::Text::ROSuperText; $SuperText = 1; $AnsiColor = 1; 1';
	eval 'use Tk::ROTextANSIColor; $AnsiColor = 1; 1'  unless ($SuperText || $viewer =~ /texthighlight/i);
	if ($viewer eq 'ROTextHighlight')
	{
		eval 'use Tk::TextHighlight::Perl; use Tk::ROTextHighlight; $haveTextHighlight = 1; 1';
		eval 'use Tk::TextHighlight::PerlCool; $havePerlCool = 1; 1';
	}
	elsif ($viewer)
	{
		eval "use Tk::$viewer; 1";
		if ($viewer =~ /SuperText/o)
		{
			$SuperText = 1;
			$viewer = '';
		}
	}
print STDERR "-???- viewer=$viewer= st=$SuperText= ac=$AnsiColor=\n"  if ($debug);
}
else
{
	if ($editor eq 'TextHighlight')
	{
		eval 'use Tk::TextHighlight; $haveTextHighlight = 1; 1';
		eval 'use Tk::TextHighlight::PerlCool; $havePerlCool = 1; 1';
	}
	elsif ($editor)
	{
		eval "use Tk::$editor; 1";
		if ($editor =~ /SuperText/o)
		{
			$SuperText = 1;
			$editor = '';
		}
	}
	else
	{
		eval 'use Tk::Text::SuperText; $SuperText = 1; 1';
	}
}
$havePerlCool = $havePerlCool ? 'PerlCool' : 'Perl';
require 'setPalette.pl';
require 'getopts.pl';

require 'JCutCopyPaste.pl';

%extraOptsHash = ();
unless (defined $focus)
{
	$focus = 1  if ($ARGV[1]);
}
$focus ||= 0;
$focustab ||= $notabs ? '' : 'Tab1';

print "-???- codetext=$codetext=\n"  if ($debug);
if ($haveTextHighlight)
{
	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	%{$extraOptsHash{texthighlight}} = (-syntax => ($codetext||$havePerlCool), 
			-autoindent => 1, 
			-rulesdir => ($codetextdir||$ENV{HOME}),
			-indentchar => ($notabs ? $tspaces : "\t"),
			-highlightInBackground => (defined $hib) ? $hib : 1
	);
	%{$extraOptsHash{rotexthighlight}} = (-syntax => ($codetext||$havePerlCool), 
			-autoindent => 1, 
			-rulesdir => ($codetextdir||$ENV{HOME}),
			-indentchar => ($notabs ? $tspaces : "\t"),
			-highlightInBackground => (defined $hib) ? $hib : 1
	);
}

#eval 'require "BindMouseWheel.pl"; $WheelMouse = 1; 1';
if ($SuperText)    #OTHER TEXT WIDGETS DON'T NEED THIS!
{
eval
	{
		require "BindMouseWheel.pl"; $WheelMouse = 1;
	};
}
#print "-eval returned =$@=  wm=$WheelMouse= package=".__PACKAGE__."=\n";

use Tk::JFileDialog;

#-----------------------

$vsn = '5.12';

$editmode = 'Edit';
if ($v)
{
#	$SuperText = 0;
	$editmode = 'View';
#	$haveTextHighlight = 0;
}

$pgmhome = $0;
$pgmhome =~ s#[^/]*$##;  #SET NAME TO SQL.PL FOR ORAPERL!
$pgmhome ||= './';
$pgmhome .= '/'  unless ($pgmhome =~ m#/$#o);
$pgmhome = 'c:/perl/bin/'  if ($bummer && $pgmhome =~ /^\.[\/\\]$/o);
print "-at 2: pgmhome=$pgmhome=\n"  if ($debug);
my (%cmdfile, %marklist, %opsysList, %alreadyHaveXMLMenu, %activeWindows, %text1Hash);
my (%scrnCnts, %saveStatus);
my $nextTab = '1';

$hometmp = (-w "${homedir}tmp") ? "${homedir}tmp" : '/tmp';
$dirsep = '/';
if ($bummer)
{
	$hometmp =~ s#\/#\\#go;
	$hometmp = '\\' . $hometmp  unless ($hometmp =~ m#^(?:\\|\w\:)#o);
	unless (-w $hometmp)
	{
		$hometmp = 'C:' . $hometmp  unless ($hometmp =~ m#^\w\:#o);
		$hometmp =~ s/^\w\:/C\:/o  unless (-w $hometmp);
		$hometmp =~ s#\/#\\#gso;
	}
	$dirsep = '\\';
}
#print "-???- hometmp=$hometmp=\n";
$startpath = '.';
@fnkeyText = (0);
$srchopts = '-nocase';
@srchTextChoices = ('');
%replTextChoices = ('' => '');
%srchOptChoices = ('' => $srchopts);
$srchTextVar = '';
$markSelected = '';

my $markMenuTop = $bummer ? 1 : 2;
eval {$host = $bummer ? 'Windows' : `uname -n`;};
chomp($host);
$host ||= 'Windows';
$titleHeader = "${host}: Perl/Tk Editor v$vsn";
print "-???- open=${pgmhome}myefonts=\n"  if ($debug);
if (($f && open(T, $f)) || open(T, ".myefonts") 
		|| open (T, "${homedir}.myefonts") || open (T, "${pgmhome}myefonts"))
{
	my $i = 0;
	while (<T>)
	{
		chomp;
		next  if (/^\#/o);
		($fontnames[$i], $fixedfonts[$i]) = split(/\:/o);
		$fixedfonts[$i] =~ s/\#.*$//o;
		$i++;
	}
	close T;
}
else
{
print "-???- COULD NOT OPEN EFONTS!\n"  if ($debug);
	$fixedfonts[0] = '-*-lucida console-medium-r-normal-*-17-*-*-*-*-*-*-*';
	$fixedfonts[1] = '-*-lucida console-medium-r-normal-*-10-*-*-*-*-*-*-*';
	$fixedfonts[2] = '-*-lucida console-medium-r-normal-*-14-*-*-*-*-*-*-*';
	$fixedfonts[3] = '-*-lucida console-medium-r-normal-*-20-*-*-*-*-*-*-*';
	$fixedfonts[4] = '-*-lucida console-medium-r-normal-*-25-*-*-*-*-*-*-*';
	$fixedfonts[5] = '-*-lucida console-medium-r-normal-*-32-*-*-*-*-*-*-*';
	@fontnames = (qw(Normal Weensey Tiny Medium Large HUGE));
}
##else
##{
##	$host = `uname -n` || 'Unix';
##	$fixedfonts[0] = '-b&h-lucidatypewriter-medium-r-normal-sans-14-100-100-100-m-80-iso8859-1';
##	$fixedfonts[1] = '-b&h-lucidatypewriter-medium-r-normal-sans-17-120-100-100-m-100-iso8859-1';
##	$fixedfonts[2] = '-b&h-lucidatypewriter-medium-r-normal-sans-20-140-100-100-m-120-iso8859-1';
##	$fixedfonts[3] = '-b&h-lucidatypewriter-medium-r-normal-sans-25-180-100-100-m-150-iso8859-1';
##	$fixedfonts[4] = '-b&h-lucidatypewriter-medium-r-normal-sans-10-*-*-*-m-*-iso8859-1';
##	$fixedfonts[5] = '-b&h-lucidatypewriter-medium-r-normal-sans-34-*-*-*-m-*-iso8859-1';
##}
chomp ($host);
$host =~ s/^([^\.]+)\..*$/$1/g;  #STRIP OFF DOMAIN NAME.
$host = "\u\L$host\E";
$width ||= 80;
$height ||= 30;
@runwidth = ($popw||64, $popw||64, $popw||40);     #(Check, Run, Eval)
@runheight = ($poph||10, $poph||16, $poph||10);
$popGeometry = 0;
$histFile ||= ($v && -e "${homedir}.myvhist") ? "${homedir}.myvhist" : "${homedir}.myehist";
$pathFile ||= ($v && -e "${homedir}.myvpaths") ? "${homedir}.myvpaths" : "${homedir}.myepaths";
$backupct = 0;
$marklist{''}[0] = ':insert:sel:';
$marklist{''}[1] = ':insert:sel:';

$fixedfont = '';
if (defined($tf))      #TINY FONT.
{
	$fixedfont = $fixedfonts[2];
}
elsif (defined($lf))   #LARGE FONT.
{
	$fixedfont = $fixedfonts[4];
}
elsif (defined($mf))   #LARGE FONT.
{
	$fixedfont = $fixedfonts[3];
}
elsif (defined($wf))   #WEENSEY FONT.
{
	$fixedfont = $fixedfonts[1];
}
elsif (defined($hf))   #HUGE FONT.
{
	$fixedfont = $fixedfonts[5];
}
elsif (defined($fn))   #FONT NUMBER SPECIFIED.
{
	$fixedfont = $fixedfonts[$fn] || $fixedfonts[0];
}
elsif (defined($font)) #USER-SELECTED FONT.
{
	if ($font =~ /^\d+$/o)
	{
		$fixedfont = $fixedfonts[$font];
	}
	else
	{
		for (my $i=0;$i<=$#fontnames;$i++)
		{
			if ($fontnames[$i] =~ /^$font/)
			{
				$fixedfont = $fixedfonts[$i];
				last;
			}
		}
		$fixedfont = $font  unless ($fixedfont);
	}
}
else                   #NORMAL FONT.
{
	$fixedfont = $fixedfonts[0];
}

#$dontaskagain = 1  unless ($ask);
$MainWin = MainWindow->new;
#$MainWin->geometry("+1+1");
$MainWin->title($titleHeader);

my $ebackupFid;
print "-???- local=${homedir}.ebackups= pgm=${pgmhome}ebackups=\n"  if ($debug);
$ebackupFid = "${homedir}.ebackups"  if (-f "${homedir}.ebackups" && -w "${homedir}.ebackups");
$ebackupFid ||= "${pgmhome}ebackups"  if (-f "${pgmhome}ebackups" && -w "${pgmhome}ebackups");

$c = $palette  if ($palette);
my $fgisblack;
$fgisblack = 1  if ($fg =~ /black/io); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!

$bgOrg = $bg;
$fgOrg = $fg;
if ($c)
{
	unless ($c eq 'none')
	{
		if ($c =~ /default/io)  #ADDED 20040827 TO ALL TEXT COLOR TO CHG W/O CHANGING PALETTE.
		{
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
			my $c0;
			$c0 = $MainWin->optionGet('tkVpalette','*')  if ($v);
			$c0 ||= $MainWin->optionGet('tkPalette','*');
			$c = $c0  if ($c0);
		}
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c);
		}
		unless ($fg)
		{
			if ($palette)
			{
				$fg = 'green';
			}
			else
			{
				$fg = $MainWin->cget('-foreground');
			}
		}
		#$bg = $MainWin->cget('-background')  unless ($bg);
		unless ($bg)
		{
			if ($palette)
			{
				$bg = 'black';
			}
			else
			{
				$bg = $MainWin->cget('-background');
			}
		}
	}
}
else
{
	if ($bummer)
	{
		if (open (T, ".Xdefaults") || open (T, "$ENV{HOME}/.Xdefaults")
			|| open (T, "${pgmhome}Xdefaults") || open (T, "/etc/Xdefaults"))
		{
			while (<T>)
			{
				chomp;
				if ($v && /tkVpalette\s*\=\s*\"([^\"]+)\"/o)
				{
					$c = $1;
					last;
				}
				if (/tkPalette\s*\=\s*\"([^\"]+)\"/o)
				{
					$c = $1;
					last;
				}
			}
			close T;
		}
	}
	else
	{
		eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
		$c = $MainWin->optionGet('tkVpalette','*')  if ($v);
		$c ||= $MainWin->optionGet('tkPalette','*');
	}
	if ($v)
	{
#		$c ||= 'bisque3';
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c)
		}
	}
	else
	{
		$fg = 'green'  unless ($fg);
		$bg = 'black'  unless ($bg);
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c)	
		}
	}
}
my ($textwidget) = 'TextUndo';
$textwidget = 'SuperText'  if ($SuperText);
$textwidget = $editor  if ($editor);

if ($v)
{
print STDERR "-???- xml=$xml= have=$haveXML=\n"  if ($debug);
	$viewer ||= 'XMLViewer'  if ($haveXML && ($xml || (!$noxml && $ARGV[0] =~ /\.(?:xml|xsd|xsl)$/io)));
	$textwidget = $viewer;
	unless ($textwidget)
	{
		$textwidget = 'ROText';
		$textwidget = 'ROTextANSIColor'  if ($AnsiColor && !$noac);
		$textwidget = 'ROSuperText'  if ($SuperText);
	}
	$SuperText = 0  if ($viewer && $viewer !~ /supertext/io);
	$AnsiColor = 0  unless ($textwidget =~ /^(?:ROSuperText|ROTextANSIColor)$/o);
}
else
{
	$SuperText = 0  if ($editor && $editor !~ /supertext/io);
	$AnsiColor = 0  unless ($textwidget =~ /^(?:SuperText|TextANSIColor)$/o);
}
my ($mytextrelief) = 'sunken';
$mytextrelief = 'groove'  if ($v);
$bottomFrame = $MainWin->Frame;
$lognbtnFrame = $bottomFrame->Frame;
#$text1Frame = $bottomFrame->Frame;
$wrap = 'none'  unless (defined($wrap));
$tagcnt = 0;

my $newsupertext;
#my @tabb;

&newTabFn();


#$textColorer = $MainWin->ColorEditor(-title => 'Select your favorite colors!');
#		unless ($bummer);

$w_menu = $MainWin->Frame(
		-relief => 'raised',
		-borderwidth => 2);
$w_menu->pack(-fill => 'x');

my $fileMenubtn = $w_menu->Menubutton(
		-text => 'File',
		-underline => 0);
$fileMenubtn->command(
		-label => 'New',
		-underline => 0,
		-command => \&newFn);
unless ($nobrowsetabs)
{
	$fileMenubtn->command(
			-label => 'New Tab',
			-underline => 4,
			-command => [\&newTabFn, 1]);
	$fileMenubtn->command(
			-label => 'Delete Tab',
			-underline => 4,
			-command => \&deleteTabFn);
}
$fileMenubtn->command(
		-label => 'Open',
		-underline => 0,
		-command => \&openFn);
$fileMenubtn->command(
		-label => 'Save',
		-underline => 0,
		-command => \&saveFn);
$fileMenubtn->command(
		-label => ($v ? 'Save Marks/Tags' : 'Save w/Marks'),
		-underline => ($v ? 5 : 7),
		-command => sub { 
			if ($v)
			{
				&saveTags($cmdfile{$activeTab}[$activeWindow]);
				&saveMarks($cmdfile{$activeTab}[$activeWindow], $activeWindow);
			}
			else
			{
				&saveFn(3);
			}
		});
$fileMenubtn->command(
		-label => 'Print',
		-underline =>0,
		-command => \&printFn);
$fileMenubtn->command(
		-label => 'Save As',
		-underline =>5,
		-command => [\&saveasFn, 1]);
$fileMenubtn->command(
		-label => 'Back up',
		-underline =>0,
		-command => [\&backupFn]);
$fileMenubtn->command(
		-label => 'Last back up',
		-underline =>0,
		-command => [\&showbkupFn]);
$fileMenubtn->command(
		-label => 'Split screen',
		-command => [\&splitScreen, 1]);
$fileMenubtn->command(
		-label => 'Single screen',
		-command => [\&splitScreen],
		-state => 'disabled');
$fileMenubtn->command(
		-label => $nb ? 'Turn on backup' : 'Turn OFF backup',
		-command => [\&toggleNB]);
$fileMenubtn->command(
		-label => 'use Perl',
		-underline =>0,
		-command => [\&resetFileType, 0]);
$fileMenubtn->command(
		-label => 'use HTML',
		-underline =>4,
		-command => [\&resetFileType, 2]);
$fileMenubtn->command(
		-label => 'use C',
		-underline =>4,
		-command => [\&resetFileType, 1]);
$scrnCnts{''} = 1;
$fileMenubtn->separator;
if ($v)
{
	$fileMenubtn->command(
			-label => 'Edit w/E',
			-command => [\&switchPgm, 1],
	);
}
else
{
	$fileMenubtn->command(
			-label => 'View w/V',
			-command => [\&switchPgm, 0]
	);
}
$fileMenubtn->command(
		-label => 'Exit',
		-underline =>1,
		-command => [\&exitFn]);

$fileMenubtn->pack(-side=>'left');


$editMenubtn = $w_menu->Menubutton(-text => 'Edit', -underline => 0);
$editMenubtn->command(
		-label => 'Goto',
		-accelerator => 'Alt-g',
		-underline =>0,
		-command => [\&doGoto]);
$editMenubtn->separator;
$editMenubtn->command(
		-label => 'Copy',
		-underline =>0,
		-command => [\&doMyCopy]);
$editMenubtn->command(
		-label => 'cuT',
		-underline =>2,
		-command => [\&doCut]);
$editMenubtn->command(
		-label => 'Paste (Clipboard)',
		-underline =>0,
		-command => [\&doPaste,'CLIPBOARD']);
$editMenubtn->command(-label => 'Paste (Primary)', -underline =>13, -command => [\&doPaste,'PRIMARY']);
$editMenubtn->separator;
$editMenubtn->command(-label => 'Colors',   -underline =>1, -command => [\&doColorEditor]);
#		unless ($bummer);
$editMenubtn->command(-label => 'Insert file',   -underline =>0, -command => [\&appendfile]);
$editMenubtn->command(-label => 'Edit This',   -underline =>1, -command => [\&editfile])
		if ($v);
$editMenubtn->command(-label => 'Undo',
		-underline =>0,
		-accelerator => 'Alt-u',
		-command => sub {
				eval { $whichTextWidget->tagDelete('savesel'); };
				eval { $whichTextWidget->tagAdd('savesel', 'sel.first', 'sel.last'); };
				$textScrolled[$activeWindow]->undo;
				eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		}
);
$editMenubtn->command(-label => 'Redo',
		-underline => 2,
		-accelerator => 'Alt-r',
		-command => sub {
				eval { $whichTextWidget->tagDelete('savesel'); };
				eval { $whichTextWidget->tagAdd('savesel', 'sel.first', 'sel.last'); };
				$textScrolled[$activeWindow]->redo;
				eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		}
);
$editMenubtn->entryconfigure('Undo', -state => 'disabled')
		unless ($text1Text->can('undo'));
$editMenubtn->entryconfigure('Redo', -state => 'disabled')
		unless ($text1Text->can('redo'));

$editMenubtn->command(-label => 'Left-indent', -underline => 0, -command => [\&doIndent,0,1]);
$editMenubtn->command(-label => 'Right-indent', -underline => 0, -command => [\&doIndent,1,1]);
$editMenubtn->command(-label => 'Lower-case', -command => [\&setcase,1]);
$editMenubtn->command(-label => 'Upper-case', -command => [\&setcase,0]);
$editMenubtn->command(-label => 'Length', -underline => 2, -command => [\&showlength]);
$editMenubtn->command(-label => 'Save Selected', -underline => 0, -command => [\&saveSelected]);
$editMenubtn->command(-label => 'Show Filename', -underline => 5, -command => [\&showFileName]);
$editMenubtn->command(-label => 'suM', -underline => 2, -command => [\&showSum]);
$editMenubtn->command(-label => 'Wrap word', -underline => 0, -command => [\&setwrap,'word']);
$editMenubtn->command(-label => 'Wrap char', -command => [\&setwrap,'char']);
$editMenubtn->command(-label => 'Wrap none', -command => [\&setwrap,'none']);
$editMenubtn->pack(-side=>'left');

my $findMenubtn = $w_menu->Menubutton(-text => 'Search', -underline => 0);
$findMenubtn->command(-label => 'Search Again', -underline =>7, -command => [\&doSearch,0]);
$findMenubtn->command(-label => 'Search Forward >', -underline => 7, -command => [\&doSearch,0,1]);
$findMenubtn->command(-label => 'Search Backward <', -underline => 7, -command => [\&doSearch,0,0]);
$findMenubtn->separator;
$findMenubtn->command(-label => 'Modify search',   -underline =>0, -command => [\&newSearch,0]);
$findMenubtn->command(-label => 'New search',   -underline =>0, -command => [\&newSearch,1]);
$findMenubtn->command(-label => 'Clear Highlights',   -underline =>0, -command => [\&clearSearch]);
$findMenubtn->pack(-side=>'left');

$markMenubtn = $w_menu->Menubutton(
		-text => 'Marks',
		-underline => 3);
$markMenubtn->pack(-side=>'left');
$markMenubtn->command(
		-label => 'Clear Marks',
		-underline => 0,
		-command => \&clearMarks);
$markMenubtn->command(
		-label => 'New Mark',
		-underline => 0,
		-command => \&addMark);

my (%markNextIndex);
#x$markMenuHash{''}{'Clear Marks'}->{index} = 0;
#x$markMenuHash{''}{'Clear Marks'}->{underline} = 0;
#x$markMenuHash{''}{'Clear Marks'}->{command} = \&clearMarks;
#x$markMenuIndex{''}[0] = 'Clear Marks';
#x$markMenuHash{''}{'New Mark'}->{index} = 1;
#x$markMenuHash{''}{'New Mark'}->{underline} = 0;
#x$markMenuHash{''}{'New Mark'}->{command} = \&addMark;
#x$markMenuIndex{''}[1] = 'New Mark';
#xxxxx$markNextIndex{''} = 2;

$fontMenubtn = $w_menu->Menubutton(
		-text => 'Fonts');
$fontMenubtn->pack(-side=>'left');
for (my $i=0;$i<=$#fontnames;$i++)
{
	$fontMenubtn->command(-label => $fontnames[$i], -underline =>0, -command => [\&setFont,$i]);
}

%themeHash = ();
if (open (T, ".myethemes") || open (T, "${homedir}.myethemes")
		|| open (T, "${pgmhome}myethemes"))
{
	$themeMenuBtn = $w_menu->Menubutton(
			-text => 'Themes');
	$themeMenuBtn->pack(-side=>'left');
	my ($themename, $themecode);
	while (<T>)
	{
		chomp;
		($themename, $themecode) = split(/\:/o);
		$themeHash{$themename} = $themecode;
		eval "\$themeMenuBtn->command(-label => '$themename', -command => sub {&setTheme('$themecode');});";
	}
	close T;
}
	$tagMenubtn = $w_menu->Menubutton(
			-text => 'Tags');
	$tagMenubtn->configure(-state => 'disabled')  unless ($newsupertext || $AnsiColor); #ADDED 20010131

	$tagMenubtn->pack(-side=>'left');
	$tagMenubtn->command(-label => 'Clear', -underline =>2, -command => [\&setTag,'clear']);
	$tagMenubtn->command(-label => 'Underline', -underline =>0, -command => [\&setTag,'ul']);
	$tagMenubtn->command(-label => 'Bold', -underline =>0, -command => [\&setTag,'bd']);
	$tagMenubtn->command(-label => 'Black', -underline =>4, -command => [\&setTag,'fgblack']);
	$tagMenubtn->command(-label => 'Red', -underline =>0, -command => [\&setTag,'fgred']);
	$tagMenubtn->command(-label => 'Green', -underline =>0, -command => [\&setTag,'fggreen']);
	$tagMenubtn->command(-label => 'Yellow', -underline =>0, -command => [\&setTag,'fgyellow']);
	$tagMenubtn->command(-label => 'Blue', -underline =>0, -command => [\&setTag,'fgblue']);
	$tagMenubtn->command(-label => 'Magenta', -underline =>0, -command => [\&setTag,'fgmagenta']);
	$tagMenubtn->command(-label => 'Cyan', -underline =>0, -command => [\&setTag,'fgcyan']);
	$tagMenubtn->command(-label => 'White', -underline =>0, -command => [\&setTag,'fgwhite']);
	$tagMenubtn->command(-label => 'Bkgd Red', -command => [\&setTag,'bgred']);
	$tagMenubtn->command(-label => 'Bkgd Green', -command => [\&setTag,'bggreen']);
	$tagMenubtn->command(-label => 'Bkgd Yellow', -command => [\&setTag,'bgyellow']);
	$tagMenubtn->command(-label => 'Bkgd Blue', -command => [\&setTag,'bgblue']);
	$tagMenubtn->command(-label => 'Bkgd Magenta', -command => [\&setTag,'bgmagenta']);
	$tagMenubtn->command(-label => 'Bkgd Cyan', -command => [\&setTag,'bgcyan']);
	$tagMenubtn->command(-label => 'Bkgd White', -command => [\&setTag,'bgwhite']);
	$tagMenubtn->command(-label => 'Save As', -command => [\&saveasFn, 2]);

if ($v)
{
	$fnMenubtn = $w_menu->Menubutton(
			-text => 'Fun',
			-state => 'disabled');
	$fnMenubtn->pack(-side=>'left');

}
else
{
	$fnMenubtn = $w_menu->Menubutton(
			-text => 'Fun',
			-underline => 1,
	);
	$fnMenubtn->pack(-side=>'left');
	for (my $i=1;$i<=12;$i++)
	{
		if (defined($fnkeyText[$i]) && length($fnkeyText[$i]) > 0)
		{
			$fnMenubtn->command(-label => ("F$i: \"".substr($fnkeyText[$i],0,20).'"'), -underline => 1, -command => [\&doGetFnKey, $i]);
		}
		else
		{
			$fnMenubtn->command(-label => "F$i: <undef>", -underline => 1, -command => [\&doGetFnKey, $i]);
		}
	}
	$fnMenubtn->separator;
	$fnMenubtn->command(-label => "Clear", -underline => 0, -command => [\&doClearFnKeys]);
	$fnMenubtn->command(-label => "Load",  -underline => 0, -command => [\&doLoadFnKeys]);
	$fnMenubtn->command(-label => "Save",  -underline => 0, -command => [\&doSaveFnKeys]);
}

$MainWin->title("$titleHeader, ${editmode}ing:  --untitled--");

$lognbtnFrame->pack(
		-side		=> 'top',
		-fill   => 'x',
		-padx   => '1m');

$text1Frame->pack(
		-side		=> 'left',
		-expand	=> 'yes',
		-fill   => 'both',
		-padx   => '2m',
		-pady   => '1m')  if ($nobrowsetabs);

$tabbedFrame->pack(
		-side		=> 'left',
		-expand	=> 'yes',
		-fill   => 'both',
		-padx   => '2m',
		-pady   => '1m')  unless ($nobrowsetabs);

if ($nobrowsetabs)
{
	$text1Frame->packPropagate('1');
	$textScrolled[0]->packPropagate('1');
	$textScrolled[1]->packPropagate('1');
	$textScrolled[0]->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-fill   => 'both');

	$textScrolled[1]->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-fill   => 'both');

	$textAdjuster->packForget();
#$textScrolled[1]->packConfigure(-side => 'bottom', -expand => 'yes', -fill => 'both');
	$textScrolled[1]->packForget();

	if ($bummer && $w32dnd)
	{
		$textScrolled[0]->DropSite(-dropcommand => [\&accept_drop, $textScrolled[0]],
			               -droptypes => 'Win32');
	}

#	$textColorer->configure(
#			-widgets=> [$text1Text, $textScrolled[$activeWindow]->Descendants])  unless ($bummer);
}

$statusLabel = $MainWin->Label(
		-justify=> 'left',
		-relief	=> 'groove',
		-borderwidth => 2,
		-text		=> 'Status Label');
$statusLabel->pack(-side => 'bottom',
		-fill	=> 'x',
		-padx	=> '2m',
		-pady	=> '1m');

$openButton = $lognbtnFrame->Button(
		-text => 'Open',
		-underline =>0,
		-command => \&openFn);
$openButton->pack(-side=>'left', -expand => 1);
$findButton = $lognbtnFrame->Button(
		-text => 'Find..',
		-underline => 2,
		-command => [\&newSearch,1]);
$findButton->pack(-side=>'left', -expand => 1);
$bkagainButton = $lognbtnFrame->Button(
		-text => '<',
	#-underline => 0,
		-command => [\&doSearch,0,0]);
$bkagainButton->pack(-side=>'left', -expand => 1);
$againButton = $lognbtnFrame->Button(
		-text => '>',
	#-underline => 0,
		-command => [\&doSearch,0,1]);
$againButton->pack(-side=>'left', -expand => 1);
$gotoButton = $lognbtnFrame->Button(
		-text => 'Goto',
		-underline => 0,
		-command => [\&doGoto]);
$gotoButton->pack(-side=>'left', -expand => 1);
$cutButton = $lognbtnFrame->Button(
		-text => 'Cut',
		-underline => 2,
		-command => [\&doCut]);
$cutButton->pack(-side=>'left', -expand => 1);
$copyButton = $lognbtnFrame->Button(
		-text => 'Copy',
		-underline => 0,
		-command => [\&doMyCopy]);
$copyButton->pack(-side=>'left', -expand => 1);
$pasteButton = $lognbtnFrame->Button(
		-text => 'Paste(V)',
		-underline => 6,
		-command => [\&doPaste]);
$pasteButton->pack(-side=>'left', -expand => 1);
$markButton = $lognbtnFrame->Button(
		-text => 'Mark',
		-underline => 0,
		-command => [\&addMark]);
$markButton->pack(-side=>'left', -expand => 1,);

$opsys = ($bummer) ? 'DOS' : 'Unix';
$opsysList{''}[0] = $opsys;
$opsysList{''}[1] = $opsys;

$asdosButton = $lognbtnFrame->JBrowseEntry(
		-label => '',
		-state => 'readonly',
		-textvariable => \$opsys,
		-choices => [qw(DOS Unix Mac)],
		-listrelief => 'flat',
		-relief => 'sunken',
		-takefocus => 0,
		-browse => 1,
		-browsecmd => sub { $opsysList{$activeTab}[$activeWindow] = $opsys },
		-noselecttext => 1);
$asdosButton->pack(
		-side   => 'left',
		-ipady  => 4);

$saveButton = $lognbtnFrame->Button(
		-text => 'Save',
		-command => [\&saveFn]);
$saveButton->pack(-side=>'left', -expand => 1);

$exitButton = $lognbtnFrame->Button(
		-text => 'Quit',
		-underline => 0,
		-command => [\&exitFn]);
$exitButton->pack(-side=>'left', -expand => 1);

$savexButton = $lognbtnFrame->Button(
		-text => 'Save & exit',
		-underline => 8,
		-command => [\&savexFn]);
$savexButton->pack(-side=>'left', -expand => 1);

$bottomFrame->pack(
		-side => 'bottom',
		-fill	=> 'both',
		-expand	=> 'yes');

$findMenubtn->entryconfigure('Search Again', -state => 'disabled');
$findMenubtn->entryconfigure('Search Forward >', -state => 'disabled');
$findMenubtn->entryconfigure('Search Backward <', -state => 'disabled');
$findMenubtn->entryconfigure('Modify search', -state => 'disabled');

$againButton->configure(-state => 'disabled');
$bkagainButton->configure(-state => 'disabled');

&setTheme($themeHash{$theme})  if ($theme && defined $themeHash{$theme});
if ($bgOrg)   #USER SPECIFIED BOTH -theme AND -bg!
{
	$bg = $bgOrg;
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-background => $bg);
}
if ($fgOrg)
{
	$fg = $fgOrg;
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-foreground => $fg);
}

($Yes,$No,$Cancel) = ('~Yes','~No','~Cancel');
$saveDialog = $MainWin->JDialog(
		-title          => 'Unsaved Changes!!',
		-text           => "Do you wish to save changes?",
		-bitmap         => 'questhead',
		-default_button => $Yes,
		-escape_button		=> $Cancel,
		-buttons        => [$Yes,$No,$Cancel],
);

$replDialog = $MainWin->JDialog(
		-title          => 'Search/Replace',
		-text           => "Replace?",
		-bitmap         => 'questhead',
		-default_button => $Yes,
		-escape_button  => $No,
		-buttons        => [$Yes,$No],
);

($OK) = ('~Ok');
$errDialog = $MainWin->JDialog(
		-title          => '-NOTE!-',
		-bitmap         => 'error',
		-buttons        => [$OK],
);

if ($ARGV[0])
{
	$ARGV[0] =~ s/^file://o;  #HANDLE KFM DRAG&DROP!
	$ARGV[0] =~ s#\\#/#go;    #FIX Windoze FILENAMES!

	$activeWindow = 0;
	if (&fetchdata($ARGV[0]))
	{
		$cmdfile{''}[0] = $ARGV[0];
		my $cmdfid = '';
		$cmdfid = &cwd()  unless ($cmdfile{''}[0] =~ m#^(?:\/|\w\:)#o );
		if ($cmdfid)
		{
			$cmdfid .= '/'  unless ($cmdfid =~ m#\/$#o);
		}
		$cmdfid .= $cmdfile{''}[0];
		$cmdfid =~ s#^\.\/#&cwd."\/"#e;
		$cmdfid =~ s!^(\~\w*)!
			my $one = $1 || $ENV{USER};
			my $t = `ls -d $one`;
			chomp($t);
			$t;
		!e;
		$startpath = $cmdfid;
		$startpath =~ s#[^\/]+$##o;
		my @histlist = ("$cmdfid\n");
		if (open(T, $histFile))
		{
			while (<T>)
			{
				push (@histlist, $_);
			}
			close T;
		}
		if (open(T, ">$histFile"))
		{
			print T shift(@histlist);
			while (@histlist)
			{
				$_ = shift(@histlist);
				print T $_   unless ($_ eq "$cmdfid\n");
			}
			close T;
		}
		(my $filePart = $cmdfile{''}[0]) =~ s#^.*\/([^\/]+)$#$1#;
		$tabbedFrame->pageconfigure($activeTab, -label => $filePart)  unless ($nobrowsetabs);
#		$activeWindow = 1;
		if ($ARGV[1])   #IF 2ND FILE SPECIFIED, SPLIT SCREEN & OPEN IN BOTTOM.
		{
			$cmdfile{''}[1] = $ARGV[1];
			&splitScreen();
			$textScrolled[1]->focus();
print "-???- setting focus to 1!\n"  if ($debug);
			$activeWindow = 1;
			$whichTextWidget = $textScrolled[1]->Subwidget($textsubwidget); #  unless (defined $focus);
			if (&fetchdata($ARGV[1]))
			{
				my $cmdfid = '';
				my $cmdfid = &cwd()  unless ($cmdfile{''}[1] =~ m#^(?:\/|\w\:)#o );
				if ($cmdfid)
				{
					$cmdfid .= '/'  unless ($cmdfid =~ m#\/$#o);
				}
				$cmdfid .= $cmdfile{''}[1];
				$cmdfid =~ s#^\.\/#&cwd."\/"#e;
				$cmdfid =~ s!^(\~\w*)!
					my $one = $1 || $ENV{USER};
					my $t = `ls -d $one`;
					chomp($t);
					$t;
				!e;
				$startpath = $cmdfid;
				$startpath =~ s#[^\/]+$##o;
				my @histlist = ("$cmdfid\n");
				if (open(T, $histFile))
				{
					while (<T>)
					{
						push (@histlist, $_);
					}
					close T;
				}
				if (open(T, ">$histFile"))
				{
					print T shift(@histlist);
					while (@histlist)
					{
						$_ = shift(@histlist);
						print T $_   unless ($_ eq "$cmdfid\n");
					}
					close T;
				}
			}
		}
	}
	else    #ADDED 20040407 SO IF FILE ARGUMENT SPECIFIED DOES NOT EXIST, "SAVE" STILL "REMEMBERS" IT!
	{
		$cmdfile{''}[0] = $ARGV[0]  if ($ARGV[0]);
	}
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{''}[$activeWindow]\"");
	$dontaskagain = 1  unless ($ask);
}
elsif (!$n && !$new)
{
	my $clipboard;
	my $useSelection = ($bummer) ? 'CLIPBOARD' : 'PRIMARY';
	eval { $clipboard = $MainWin->SelectionGet(-selection => $useSelection); };
	if ($clipboard)
	{
		$textScrolled[$activeWindow]->insert('end',$clipboard);
		$MainWin->title("$titleHeader, ${editmode}ing:  \"--SELECTED TEXT--\"");
		$_ = "..Successfully opened Selected Text.";
		&setStatus( $_);
		$textScrolled[$activeWindow]->markSet('insert','0.0');
	}
	else
	{
		$MainWin->title("${host}: Perl/Tk Editor, bv$vsn, ${editmode}ing:  \"--NEW DOCUMENT--\"");
	}
	$cmdfile{''}[0] = '';
}

$filetype = 0;

if ($cmdfile{''}[0] =~ /\.c$/io || $cmdfile{''}[0] =~ /\.h$/io || $cmdfile{''}[0] =~ /\.cpp$/io)
{
	#eval {require 'e_c.pl';};  #EVAL DOESN'T WORK HERE IN COMPILED VSN.
	require 'e_c.pl';
	$filetype = 1;
}
elsif ($cmdfile{''}[0] =~ /\..*ht[a-z]+/io)
{
	#eval {require 'e_htm.pl';};
	require 'e_htm.pl';
	$filetype = 2;
}
else
{
	#eval {require 'e_pl.pl';};
	require 'e_pl.pl';
}
$fileTypes{$filetype} = 1;

#!!$textScrolled[$activeWindow]->bind('<Alt-Key>',['Backspace','Insert']);
($text1Text,@textchildren) = $textScrolled[$activeWindow]->children;
$MainWin->bind('<Alt-b>' => [\&gotoMark, '_Bookmark']);

#SPECIAL CODE IF VIEWING ONLY!

if ($v)
{
	$editMenubtn->entryconfigure('cuT', -state => 'disabled');
	$editMenubtn->entryconfigure('Paste (Clipboard)', -state => 'disabled');
	$editMenubtn->entryconfigure('Paste (Primary)', -state => 'disabled');
	$editMenubtn->entryconfigure('Undo', -state => 'disabled');
	$editMenubtn->entryconfigure('Redo', -state => 'disabled');
	$editMenubtn->entryconfigure('Left-indent', -state => 'disabled');
	$editMenubtn->entryconfigure('Right-indent', -state => 'disabled');
	$editMenubtn->entryconfigure('Insert file', -state => 'disabled');
	$fileMenubtn->entryconfigure('Save', -state => 'disabled');
	$asdosButton->configure(-state => 'disabled');
	$cutButton->configure(-state => 'disabled');
	$pasteButton->configure(-state => 'disabled');
	$saveButton->configure(-state => 'disabled');
	$savexButton->configure(-state => 'disabled');
	$MainWin->bind('<Escape>' => \&exitFn);
	#$MainWin->bind('<Alt-c>' => 'NoOp');
	#$MainWin->bind('<Alt-c>' => sub {&doCopy; shift->break;});  #NEEDED SINCE COLORS REBINDS 
	                                        #ALT-C TO IT'S MENUBUTTON (AFTER)
	                                        #OUR BUTTON AUTOBINDS ALT-C! :-(
	                                        #DOESN'T WORK :---(((
}

#NEXT 4 ADDED 20031107 FOR IMWHEEL.
$MainWin->bind('<Alt-Left>' => sub { 
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->xview('scroll', -1, 'units');
});
$MainWin->bind('<Alt-Right>' => sub { 
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->xview('scroll', +1, 'units');
});
$MainWin->bind('<Alt-Up>' => sub { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->yview('scroll', -1, 'units') });
$MainWin->bind('<Alt-Down>' => sub { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->yview('scroll', +1, 'units') });

if (defined $tab1 && !($nobrowsetabs))
{
	my $tabX;
	my $i = 1;
	while (1)
	{
		$tabX = '';
		eval "\$tabX = \$tab$i  if (defined \$tab$i)";
		last  unless ($tabX);
		my ($topfid, $bottomfid) = split(/\:/o, $tabX);
		&newTabFn();
		$activeWindow = 0;
		&openFn($topfid);
		if ($bottomfid)
		{
			&splitScreen();
			$textScrolled[1]->focus();
			$activeWindow = 1;
			&openFn($bottomfid);
		}
		++$i;
	}
}

print "-???1- focus=$focus= aw=$activeWindow= fns=$focusNotSet\n"  if ($debug);
unless ($focusNotSet)
{
	$activeWindow = ($focus == 1) ? 1 : 0;
}
####????$textScrolled[1]->Subwidget($textsubwidget)->focus();
print "-???2- focus=$focus= aw=$activeWindow=\n"  if ($debug);
if ($nobrowsetabs)
{
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
}
else
{
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$tabbedFrame->raise($focustab);
}
$activeWindows{$activeTab} = $activeWindow;
&gotoMark($textScrolled[$activeWindow],$l)  if ($l);
if ($s)
{
	push (@srchTextChoices, $s);
	$srchOptChoices{$s} = '-nocase';
	$replTextChoices{$s} = '';
	&doSearch(2);
}

#MainLoop;
while (Tk::MainWindow->Count)
{
	if ($childpid)
	{
		if ($childpid)
		{
			@children = `ps ef|grep "$childpid"|grep -v "grep"`;
			$childstillrunning = 0;
			while (@children)
			{
				$_ = shift(@children);
				if (/^\D*(\d+)/o)
				{
					$childstillrunning = 1  if ($1 eq $childpid);
				}
			}
			unless ($childstillrunning)
			{
				#++$abortit;
				#$abortButton->configure(-text => 'Fetch Output');
				$abortButton->invoke  if (Exists($xpopup2) && $abortButton);
				$childpid = '';
			}
		}
		eval { $xpopup2->update  }  if (Exists($xpopup2));
	}
	DoOneEvent(ALL_EVENTS);
}

sub newFn
{
	my ($usrres);
	$usrres = $No;
	unless ($v)
	{
		if (length($textScrolled[$activeWindow]->get('1.0','3.0')) > 1)
		{
			$saveDialog->configure(
					-text => "Save any changes to $cmdfile{$activeTab}[$activeWindow]?");
			$usrres = $saveDialog->Show();		
			$cmdfile{$activeTab}[$activeWindow] ||= "$hometmp/e.out.tmp";
		}
	}
	$_ = '';
	$usrres = $Cancel x &writedata($cmdfile{$activeTab}[$activeWindow])  if ($usrres eq $Yes);
	return  if ($usrres eq $Cancel);
	$cmdfile{$activeTab}[$activeWindow] = '';
	$textScrolled[$activeWindow]->delete('0.0','end');
	&clearMarks();
	$opsysList{$activeTab}[$activeWindow] = $bummer ? 'DOS' : 'Unix';
	$MainWin->title("$titleHeader, ${editmode}ing:  New File");
	unless ($activeWindow)
	{
		(my $numberPart = $activeTab) =~ s#\D##gs;
		$tabbedFrame->pageconfigure($activeTab, -label => "Tab $numberPart")  unless ($nobrowsetabs);
	}
}

sub newTabFn
{
	my $openDialog = shift || 0;

	$activeWindow = 0;
	if ($nobrowsetabs)
	{
		$text1Frame = $bottomFrame->Frame;
		$activeTab = '';
		$activeWindow = ($focus == 1) ? 1 : 0;
		$activeWindows{$activeTab} = $activeWindow;
	}
	else
	{
#print "-???- nextTab=$nextTab= active=$activeTab:$activeWindow=(".$activeWindows{"Tab$nextTab"}.") f=$focus= ft=$focustab=\n";
		$activeTab = "Tab$nextTab";
		$activeWindow = ($focus == 1 && $activeTab eq $focustab) ? 1 : 0;
		$activeWindows{$activeTab} = $activeWindow;
#		my $bgcolr = $MainWin->cget( -background );    #NEXT 2 MAKE TAB ROW SAME COLOR AS REST OF WINDOW:
		$tabbedFrame = $bottomFrame->NoteBook()  unless ($nextTab > 1);
#		$tabbedFrame = $bottomFrame->NoteBook(-backpagecolor => $bgcolr)  unless ($nextTab > 1);
print STDERR "-newTabFn: nextTab=$nextTab= tabbedFrame=$tabbedFrame=\n"  if ($debug);
#		$tabb[$nextTab] = $tabbedFrame->add( $activeTab, -label=> "Tab $nextTab", -raisecmd => [\&chgTabs, $nextTab]);
#		$text1Frame = $tabb[$nextTab];
		$text1Frame = $tabbedFrame->add( $activeTab, -label=> "Tab $nextTab", -raisecmd => [\&chgTabs, $nextTab]);
		++$nextTab;
	}
	if ($SuperText && !$noac && !$v)
	{
		$textsubwidget = $SuperText ? 'supertext' : 'textundo';
		$textScrolled[0] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se', -ansicolor => 1);
		$textScrolled[0]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[0]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$textAdjuster = $text1Frame->Adjuster();
		$textScrolled[1] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se', -ansicolor => 1);
		$textScrolled[1]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[1]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$newsupertext = 1;
	}
	unless ($newsupertext)
	{
		$textScrolled[0] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se');
		$textScrolled[0]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[0]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$textAdjuster = $text1Frame->Adjuster();
		$textScrolled[1] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se');
		$textScrolled[1]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[1]->Subwidget('yscrollbar')->configure(-takefocus => 0);
	}
	$text1Hash{$activeTab}[0] = $textScrolled[0];
	$text1Hash{$activeTab}[1] = $textScrolled[1];
	$text1Hash{$activeTab}[2] = $textAdjuster;
#	$activeWindows{$activeTab} = 0;
	$scrnCnts{$activeTab} = $scrnCnt;
print STDERR "---new tab:  active=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	Tk::Autoscroll::Init($textScrolled[0])  if ($autoScroll);
	&BindMouseWheel($textScrolled[0])  if ($WheelMouse);
	&BindMouseWheel($textScrolled[1])  if ($WheelMouse);

	if ($v)
	{
		$textsubwidget = ($AnsiColor && !$noac) ? 'rotextansicolor' : 'rotext';
		$textsubwidget = 'rosupertext'  if $SuperText;
		$textsubwidget = "\L$viewer\E"  if ($viewer);
print STDERR "-subwidget=$textsubwidget= viewer=$viewer= ST=$SuperText=\n"  if ($debug);
		$text1Text = $textScrolled[0]->Subwidget($textsubwidget);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
			#-font	=> '-*-lucida console-medium-r-normal-*-18-*-*-*-*-*-*-*',
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
			#-font	=> '-*-lucida console-medium-r-normal-*-18-*-*-*-*-*-*-*',
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
	}
	else
	{
		$textsubwidget = $SuperText ? 'supertext' : 'textundo';
		$textsubwidget = "\L$editor\E"  if ($editor);
		print STDERR "-subwidget=$textsubwidget= viewer=$viewer= ST=$SuperText=\n"  if ($debug);
		$text1Text = $textScrolled[0]->Subwidget($textsubwidget);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
		#THIS KLUDGE NECESSARY BECAUSE DUAL-SPEED SETPALETTE BROKEN ON WINDOZE!
	}
	if ($haveTextHighlight && ($editor =~ /texthighlight/io || $viewer =~ /texthighlight/io))
	{
		my $sections;
		($sections, $kateExtensions) = $textScrolled[0]->Subwidget($textsubwidget)->fetchKateInfo;
		$textScrolled[0]->Subwidget($textsubwidget)->addKate2ViewMenu($sections);
		$textScrolled[1]->Subwidget($textsubwidget)->addKate2ViewMenu($sections);
		if (open(T, ".myemimes") 
			|| open (T, "${homedir}.myemimes") || open (T, "${pgmhome}myemimes"))
		{
			my ($fext, $ft);

			while (<T>)
			{
				chomp;
				s/\#.*$//o;
				next  unless (/\S/o);
				($fext, $ft) = split(/\:/o, $_, 2);
				$mimeTypes{$fext} = $ft;
			}
			close T;
		}
	}

	$whichTextWidget = $textScrolled[0]->Subwidget($textsubwidget);
	unless ($nobrowsetabs)
	{
print "-???- raising1 aw=$activeWindow=\n"  if ($debug);
		$tabbedFrame->raise($activeTab);
		$r = $tabbedFrame->raised();
	}
#print "-???- NOW CURRENT=$r=\n";
$text1Frame->packPropagate('1');
$textScrolled[0]->packPropagate('1');
$textScrolled[1]->packPropagate('1');
$textScrolled[0]->pack(
		-side   => 'bottom',
		-expand => 'yes',
		-fill   => 'both');

$textScrolled[1]->pack(
		-side   => 'bottom',
		-expand => 'yes',
		-fill   => 'both');

$textAdjuster->packForget();
#$textScrolled[1]->packConfigure(-side => 'bottom', -expand => 'yes', -fill => 'both');
$textScrolled[1]->packForget();
if ($bummer && $w32dnd)
{
	$textScrolled[0]->DropSite(-dropcommand => [\&accept_drop, $textScrolled[0]],
		               -droptypes => 'Win32');
}

	$textScrolled[0]->bind('<FocusIn>' => sub {
			&textfocusin; $activeWindow = 0; $activeWindows{$activeTab} = 0;
			$whichTextWidget = $textScrolled[0]->Subwidget($textsubwidget);
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
			$opsys = $opsysList{$activeTab}[$activeWindow];
			&resetMarks();
			$statusLabel->configure( -text => $saveStatus{$activeTab}[0]);
	});
	$textScrolled[1]->bind('<FocusIn>' => sub {
			&textfocusin; $activeWindow = 1; $activeWindows{$activeTab} = 1;
			$whichTextWidget = $textScrolled[1]->Subwidget($textsubwidget);
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
			$opsys = $opsysList{$activeTab}[$activeWindow];
			&resetMarks();
			$statusLabel->configure( -text => $saveStatus{$activeTab}[1]);
	});
	for (my $i=0;$i<=1;$i++)
	{
		my @bindTags = $textScrolled[$i]->Subwidget($textsubwidget)->bindtags;
#REMOVED - MESSES UP AUTOINDENT?!?!?!
#		$textScrolled[$i]->Subwidget($textsubwidget)->bindtags([$bindTags[1], $bindTags[0], @bindTags[2 .. $#bindTags]]);  #REVERSE BIND ORDER PROCESSING.

		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<Alt-l>' => [\&shocoords,0]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F1>' => [\&doFnKey,1]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F2>' => [\&doFnKey,2]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F3>' => [\&doFnKey,3]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F4>' => [\&doFnKey,4]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F5>' => [\&doFnKey,5]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F6>' => [\&doFnKey,6]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F7>' => [\&doFnKey,7]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F8>' => [\&doFnKey,8]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F9>' => [\&doFnKey,9]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F10>' => [\&doFnKey,10]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F11>' => [\&doFnKey,11]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F12>' => [\&doFnKey,12]);
#		$textScrolled[$i]->Subwidget($textsubwidget)->bindtags(\@bindTags);  #REVERSE BIND ORDER PROCESSING.
#		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<Return>', sub { shift->doAutoIndent(1); })  #TRIED TO FIX AUTOINDENT, CAN'T HAVE BOTH F3 & AUTOINDENT WORK?!?!?!
	}
	#NEXT 4 BINDINGS NEEDED BECAUSE OF TK-BUG IN Text, AND TextHighlight *Control-Tab BINDINGS!
	unless ($v)
	{
		$textScrolled[0]->Subwidget($textsubwidget)->bind('<Control-Tab>' => sub
		{
			#my $w = shift;
			#$w->focusNext;     #THIS FUNCTION BRINGS SYSTEM TO KNEES BY GOBBLING UP ALL MEMORY+SWAP?!?!?!?!
			if ($scrnCnts{$activeTab} == 2)
			{
				$textScrolled[1]->Subwidget($textsubwidget)->focus;
			}
			else
			{
				$openButton->focus;
			}
			Tk->break;
		});
		$textScrolled[1]->Subwidget($textsubwidget)->bind('<Control-Tab>' => sub
		{
			#my $w = shift;
			#$w->focusNext;
			$openButton->focus;
			Tk->break;
		});     #NEXT 2 BINDINGS DON'T WORK FOR SUPERTEXT - JUST DON'T PRESS EM!
		$textScrolled[0]->Subwidget($textsubwidget)->bind('<Shift-Control-Tab>' => sub
		{
			if ($nobrowsetabs)
			{
				$exitButton->focus;
			}
			else
			{
				$exitButton->focusNext->focus;
			}
			Tk->break;
		});
		$textScrolled[1]->Subwidget($textsubwidget)->bind('<Shift-Control-Tab>' => sub
		{
			$textScrolled[0]->Subwidget($textsubwidget)->focus;
			Tk->break;
		});
	}

	if ($SuperText == 1 || $editor =~ /texthighlight/io)
	{
		$textScrolled[0]->bind('<Control-p>' => sub
		{
				$textScrolled[0]->Subwidget($textsubwidget)->markSet('_prev','insert');
				$textScrolled[0]->Subwidget($textsubwidget)->jumpToMatchingChar();
				&shocoords(0);
		});
		$textScrolled[1]->bind('<Control-p>' => sub
		{
				$textScrolled[1]->Subwidget($textsubwidget)->markSet('_prev','insert');
				$textScrolled[1]->Subwidget($textsubwidget)->jumpToMatchingChar();
				&shocoords(0);
		});
	}
	$opsys = ($bummer) ? 'DOS' : 'Unix';
	my @tablist = $tabbedFrame->pages();
	for (my $i=0;$i<=1;$i++)
	{
		$opsysList{$activeTab}[$i] = $opsys;

		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<ButtonRelease-1>' => [\&shocoords,1]);
		$textScrolled[$i]->bind('<Alt-comma>' => sub { &doSearch(0,0) });
		$textScrolled[$i]->bind('<Alt-period>' => sub { &doSearch(0,1) });
		$textScrolled[$i]->bind('<Alt-a>' => sub { &doSearch(0) });
		$textScrolled[$i]->bind('<Control-g>' => sub { &doSearch(0,1) });
		my $cls = ref($textScrolled[$i]->Subwidget($textsubwidget));
 		$textScrolled[$i]->Subwidget($textsubwidget)->bind($cls, '<Control-Key-'.scalar(@tablist).'>' => sub{});
		$textScrolled[$i]->Subwidget($textsubwidget)->bind($cls, '<Alt-Tab>' => sub{});
	}
	$textScrolled[0]->Subwidget($textsubwidget)->bind('<Alt-Tab>' => sub
	{
#3		if ($nobrowsetabs)    #UNCOMMENT #3 TO HAVE ALT-TAB TRY TO GO TO NEXT BROWSER "TAB".
#3		{
			if ($scrnCnts{$activeTab} == 2)
			{
				$textScrolled[1]->Subwidget($textsubwidget)->focus;
			}
#4			else
#4			{
#4				$openButton->focus;
#4			}
#3		}
#3		else
#3		{
#3			my @tablist = $tabbedFrame->pages();
#3			my $nextTab = $tabbedFrame->info('focusnext');
#3			if ($nextTab && $#tablist > 0)
#3			{
#3				$tabbedFrame->raise($nextTab);
#3			}
#3			else
#3			{
#3				if ($scrnCnts{$activeTab} == 2)
#3				{
#3					$textScrolled[1]->Subwidget($textsubwidget)->focus;
#3				}
#3				else
#3				{
#3					$openButton->focus;
#3				}
#3			}
#3		}
		Tk->break;
	});
	$textScrolled[1]->Subwidget($textsubwidget)->bind('<Alt-Tab>' => sub
	{
		$textScrolled[0]->Subwidget($textsubwidget)->focus;
		Tk->break;
	});
	$textScrolled[$activeWindow]->markSet('insert','0.0');
	&openFn()  if ($openDialog);
#DOESN'T WORK EXCEPT FOR SUPERTEXT (I CAN'T GET RED OF "Text" WIDGET'S DEFAULT BINDINGS?!
	$MainWin->bind('<Control-Key-'.scalar(@tablist).'>' => sub
	{
		$tabbedFrame->raise($tablist[$#tablist]);
		Tk->break;
	});
}

sub deleteTabFn
{
	my $usrres = $No;
	$saveDialog->configure(
			-text => "DELETE current tab?");
	$usrres = $saveDialog->Show();
	if ($usrres eq $Yes)
	{
		return  if (&exitFn($No, 'NOEXIT', $activeTab) eq $Cancel);
		$tabbedFrame->delete($activeTab);
	}
}

sub chgTabs
{
	my $thisTab = shift;

	my $r = $tabbedFrame->raised();
	$activeTab = $r;
#	print "-chgTabs: args=".join('|',@_)."= THISTAB=$thisTab= CURRENT=$activeTab=\n";
	$textScrolled[0] = $text1Hash{$activeTab}[0];
	$textScrolled[1] = $text1Hash{$activeTab}[1];
	$activeWindow = $activeWindows{$activeTab};
#	$scrnCnt = $scrnCnts{$activeTab};
	if (defined $fileMenubtn)
	{
		if ($scrnCnts{$activeTab} == 2)
		{
			$fileMenubtn->entryconfigure('Single screen',  -state => 'normal');
			$fileMenubtn->entryconfigure('Split screen',  -state => 'disabled');
		}
		else
		{
			$fileMenubtn->entryconfigure('Single screen',  -state => 'disabled');
			$fileMenubtn->entryconfigure('Split screen',  -state => 'normal');
		}
	}
	$textAdjuster = $text1Hash{$activeTab}[2];
print "-1--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	&resetMarks();
}

sub openFn		#File.Open (Open a different command file)
{
	my ($openfid) = shift;
	my ($usrres);
	$usrres = $No;
	unless ($v)
	{
		if (length($textScrolled[$activeWindow]->get('1.0','3.0')) > 1)
		{
			$saveDialog->configure(
					-text => "Save any changes to $cmdfile{$activeTab}[$activeWindow]?");
			$usrres = $saveDialog->Show();
			&fixAfterStep  if ($steppin);
			$cmdfile{$activeTab}[$activeWindow] ||= "$hometmp/e.out.tmp";
		}
	}
	$_ = '';
	$usrres = $Cancel x &writedata($cmdfile{$activeTab}[$activeWindow])  if ($usrres eq $Yes);
	return  if ($usrres eq $Cancel);
	my ($savefile) = $cmdfile{$activeTab}[$activeWindow];
	if ($openfid || !&getcmdfile("Select file to $editmode"))
	{
		$cmdfile{$activeTab}[$activeWindow] = $openfid  if ($openfid);
		&clearMarks();
		if (&fetchdata($cmdfile{$activeTab}[$activeWindow]))
		{
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
			unless ($activeWindow)
			{
				(my $filePart = $cmdfile{$activeTab}[$activeWindow]) =~ s#^.*\/([^\/]+)$#$1#;
				$tabbedFrame->pageconfigure($activeTab, -label => $filePart)  unless ($nobrowsetabs);
			}
		}
		else
		{
			$cmdfile{$activeTab}[$activeWindow] = $savefile;
		}
	}
	else
	{
		$cmdfile{$activeTab}[$activeWindow] = $savefile  unless (defined($cmdfile{$activeTab}[$activeWindow]));
	}
}

sub saveSelected
{
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => 'File to save selected text to:',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 16,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => 1);

	my $fid = $fileDialog->Show;
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	return  unless ($fid =~ /\S/o);
	$_ = '';

	if ($newsupertext || $AnsiColor)
	{
		eval {$_ = $textScrolled[$activeWindow]->getansi('sel.first','sel.last');};
	}
	else
	{
		eval {$_ = $textScrolled[$activeWindow]->get('sel.first','sel.last');};
	}
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');
	$_ .= "\n"  if ($_ && $lastpos =~ /\.0$/o);
	if ($newsupertext || $AnsiColor)
	{
		$_ = $textScrolled[$activeWindow]->getansi('0.0','end')  unless ($_);
	}
	else
	{
		$_ = $textScrolled[$activeWindow]->get('0.0','end')  unless ($_);
	}
	return (&writedata($fid, 1, 2));
}

sub saveFn		#File.Save (Save changes to command file)
{
	my $saveopt = shift || 0;
	my ($cancel) = 0;
	$cancel = &getcmdfile("Save file as")  unless ($cmdfile{$activeTab}[$activeWindow] =~ /\S/);
	return ($cancel)  if ($cancel);   #getcmdfile() returns 1 if no filename entered!
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
	$_ = '';
	my $usrres = $Yes;
	if (-e $cmdfile{$activeTab}[$activeWindow])
	{
		my (@fidinfo) = stat($cmdfile{$activeTab}[$activeWindow]);
		my $msg;
#		$msg = "file \"$cmdfile[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
#				if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
		$msg = "file \"$cmdfile{$activeTab}[$activeWindow]\"\nexists! overwrite?"
				unless ($msg || $dontaskagain);
		if ($msg)
		{
			$usrres = $Cancel;
			$saveDialog->configure(
					-text => $msg);
			$usrres = $saveDialog->Show();
		}
	}
	if ($usrres eq $Yes)
	{
		$dontaskagain = 1  unless ($ask > 1);   #IF ASK=2, THEN ALWAYS ASK!
		return (&writedata($cmdfile{$activeTab}[$activeWindow], 0, $saveopt));
	}
}

sub printFn
{
	my ($printedselected);
	if (open(T, "<${homedir}.myeprint"))
	{
		$intext = <T>;
		chomp ($intext);
	}
	&gettext("Print cmd:",25,'t',0,0,1);
	return 0  unless ($intext && $intext ne '*cancel*');
	if (open (T, ">${homedir}.myeprint"))
	{
		print T "$intext\n";
		close T;
	}
	$_ = '';
	if ($newsupertext || $AnsiColor)
	{
		eval {$_ = $textScrolled[$activeWindow]->getansi('sel.first','sel.last');};
	}
	else
	{
		eval {$_ = $textScrolled[$activeWindow]->get('sel.first','sel.last');};
	}
	if ($_)
	{
		my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');
		$_ .= "\n"  if ($_ && $lastpos =~ /\.0$/o);
		$printedselected = 1;
	}
	&writedata("$hometmp/e.out.tmp", $printedselected, 2);
	my $mytitle = $cmdfile{$activeTab}[$activeWindow];
	$mytitle =~ s/\s/_/g;
	$intext .= " -o\"title=$mytitle\" "  if ($cmdfile{$activeTab}[$activeWindow] && $intext =~ /post/o && $intext !~ /title/o);  #SPECIAL FEATURE FOR MY "POST" SCRIPTS!
	if ($intext =~ /^\s*\|/o)
	{
		`cat $hometmp/e.out.tmp $intext &`;
	}
	else
	{
		`$intext $hometmp/e.out.tmp`;
	}
	if ($?)
	{
		&setStatus("..Could not print ($intext) - $?.");
	}
	elsif ($printedselected)
	{
		&setStatus("..printed ($intext) selected text.");
	}
	else
	{
		&setStatus("..printed ($intext) all text.");
	}
}

sub exitFn 	#File.Save (Save changes to command file)
{
	my $saveDefaultYN = shift || $No;
	my $noExit = shift || 0;
	my $currentTabOnly = shift || 0;

	my ($cancel) = 0;
	$_ = '';
	my ($msg, @wins);
	my $saveTab = $activeTab;
	my $saveActive0 = $activeWindow;
	my @tablist = ($nobrowsetabs || $currentTabOnly) ? $activeTab : $tabbedFrame->pages();
	my $tabNum = 1;
	my ($usrres);
TABLOOP: 	foreach $activeTab (@tablist)
	{
		$textScrolled[0] = $text1Hash{$activeTab}[0];
		$textScrolled[1] = $text1Hash{$activeTab}[1];
		$activeWindow = $activeWindows{$activeTab};
		if ($scrnCnts{$activeTab} == 2)
		{
			@wins = (0, 1);
		}
		else
		{
			@wins = ($activeWindow);
		}
		my $saveActive = $activeWindow;
		my $saveActiveWindowFromFocus;
		my $whichWindowIndicator = ($#wins >= 1) ? '(Top window) ' : '';
		$whichWindowIndicator = ($nobrowsetabs ? '' : "Tab# $tabNum: ") . $whichWindowIndicator;
WINDOWLOOP:		foreach $activeWindow (@wins)
		{
			$usrres = $saveDefaultYN;
			$_ = '';
			#DEFAULT=NO OR CMDFILE IS EMPTY OR (ASKAGAIN && CMDFILE EXISTS):
			if ($saveDefaultYN eq $No || $cmdfile{$activeTab}[$activeWindow] !~ /\S/o || (!$dontaskagain && -e $cmdfile{$activeTab}[$activeWindow]))
			{
				$saveActiveWindowFromFocus = $activeWindow;
				$whichWindowIndicator =~ s/Top/Bottom/o  if ($activeWindow);
				unless ($v || $cmdfile{$activeTab}[$activeWindow] =~ /\S/o)
				{
					$usrres = $No;
#$_ = length($textScrolled[$activeWindow]->get('1.0','3.0'));
#print "-????- length=$_=\n";
					if (length($textScrolled[$activeWindow]->get('1.0','3.0')) > 1)
					{
						$saveDialog->configure(
								-text => "Save ${whichWindowIndicator}data to a file?");
						$usrres = $saveDialog->Show();
						if ($usrres eq $No)
						{
							&backupFn("e.after$activeWindow.tmp")  unless ($v);
						}
					}
					next  unless ($usrres eq $Yes);
					&getcmdfile("Save ${whichWindowIndicator}data as");
				}
				$msg = '';
				if (-e $cmdfile{$activeTab}[$activeWindow])
				{
					$msg = "${whichWindowIndicator}file \"$cmdfile{$activeTab}[$activeWindow]\"\nexists! overwrite?";
					if ($chkacc)
					{
						my (@fidinfo) = stat($cmdfile{$activeTab}[$activeWindow]);
						$msg = "${whichWindowIndicator}file \"$cmdfile{$activeTab}[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
								if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
					}
				}
				elsif ($usrres eq $No)
				{
					$msg = "Save any ${whichWindowIndicator}changes to $cmdfile{$activeTab}[$activeWindow]?";
				}
				if ($msg)
				{
					$saveDialog->configure(
							-text => $msg);
					$usrres = $saveDialog->Show()  unless ($v);
				}
				$activeWindow = $saveActiveWindowFromFocus;
			}
			$_ = '';
#print "-exitFn:  USERRES=$usrres= CANCEL=$Cancel=\n";
			if ($usrres eq $Yes)
			{
#			$dontaskagain = 1  unless ($ask > 1);
#print "-???- exitFn: actTab=$activeTab= actWin=$activeWindow= fid=".$cmdfile{$activeTab}[$activeWindow]."=\n";
				return  if (&writedata($cmdfile{$activeTab}[$activeWindow]));
				print "..File \"$cmdfile{$activeTab}[$activeWindow]\" saved.\n";
			}
			elsif ($usrres eq $No)
			{
				&backupFn("e.after$activeWindow.tmp")  unless ($v);
			}
			elsif ($usrres eq $Cancel)
			{
#print "-exitFn: exit loop (CANCEL)!\n";
				last TABLOOP;
			}
		}
		$activeWindow = $saveActive;
		++$tabNum;
	}
	$activeTab = $saveTab;
	$textScrolled[0] = $text1Hash{$activeTab}[0];
	$textScrolled[1] = $text1Hash{$activeTab}[1];
	$activeWindow = $saveActive0;
#print "-exitFn - 2:  USERRES=$usrres= CANCEL=$Cancel=\n";
	if ($usrres ne $Cancel)
	{
#print "-exitFn: user did NOT cancel, so exit!\n";
		exit (0)  unless ($noExit);
	}
	return $usrres;
}

sub saveasFn		#File.save As (Save under new name)
{
	my ($savefile) = $cmdfile{$activeTab}[$activeWindow];
	my $saveopt = shift;

	unless (&getcmdfile("Save file as"))
	{
		my ($usrres) = $Yes;
		if (!$dontaskagain && -e $cmdfile{$activeTab}[$activeWindow])
		{
			$usrres = $Cancel;
			$saveDialog->configure(
					-text => "file \"$cmdfile{$activeTab}[$activeWindow]\"\nexists! overwrite?");
			$usrres = $saveDialog->Show();
		}
		$_ = '';
		if ($usrres eq $Yes)
		{
			&writedata($cmdfile{$activeTab}[$activeWindow], 0, $saveopt);
			$dontaskagain = 1  unless ($ask > 1);
		}
	}
#	$cmdfile{$activeTab}[$activeWindow] = $savefile;	 #KEEP OLD FILENAME AS DEFAULT SAVE / COMMENT OUT TO MAKE SAVE-AS NAME THE DEFAULT SAVE NAME FOR FUTURE SAVES!
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
}

sub getcmdfile          #PROMPT USER FOR NAME OF DESIRED COMMAND FILE.  RETURNS 1 ON FAILURE/CANCEL
{
	my ($opt) = shift;
	$intext = undef;
	local $_;
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => $opt || 'Select file to edit',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 16,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => 1);
	$intext = $fileDialog->Show;
	&fixAfterStep()  if ($Steppin);   #TRYIN TO MAKE OUR STUPID W/M RESTORE FOCUS?!?!?! :(
print "-3--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus();
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	$intext = undef  if ($intext !~ /\S/o);
	if (defined($intext))
	{
		$cmdfile{$activeTab}[$activeWindow] = $intext;
		$dontaskagain = 0  if ($ask);
	}
	return $cmdfile{$activeTab}[$activeWindow]  unless ($opt);   #APPEARS NOT 2B USED.
	return (1)  unless (defined($intext));
	return (0);
}

sub fetchdata
{
	my ($fid) = shift;
	my ($backups);
	if (open(INFID,$fid))
	{
		my (@fidinfo) = stat($fid);
		$fileLastUpdated = $fidinfo[8];
		binmode INFID;
		$textScrolled[$activeWindow]->delete('0.0','end');
		&clearMarks();
		for ($i=1;$i<=$tagcnt;$i++)
		{
			eval {$whichTextWidget->tagDelete("foundme$i");};
		}
		$tagcnt = 0;
		$_ = <INFID>;
		$opsys = (s/\r\n/\n/go) ? 'DOS' : 'Unix';
		$opsys = 'Mac'  if (s/\r/\n/go);
		$opsysList{$activeTab}[$activeWindow] = $opsys;
		my $indata = $_;
		while (<INFID>)
		{
			s/\r\n?/\n/go;
			$indata .= $_;
		}
		close INFID;
		if ($textsubwidget =~ /xmlviewer/io)
		{
			$textScrolled[$activeWindow]->insertXML(-text => $indata);
			unless (defined($alreadyHaveXMLMenu{$activeTab}[$activeWindow])
					&& $alreadyHaveXMLMenu{$activeTab}[$activeWindow])
			{
				$textScrolled[$activeWindow]->XMLMenu;
				$alreadyHaveXMLMenu{$activeTab}[$activeWindow] = 1;
			}
		}
		else
		{
			if ($haveTextHighlight && ($editor =~ /texthighlight/io || $viewer =~ /texthighlight/io))
			{
				my $fext = '';
				$fext = $1  if ($fid =~ /\.(\w+)$/o);
				if ($codetext)
				{
					my $langModule = ($codetext eq 'Kate') ? &kateExt($fid) : $codetext;
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => $langModule);
				}
				elsif ($mimeTypes{$fext})
				{
print STDERR "-chose $mimeTypes{$fext} from mime file!\n"  if ($debug);
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => $mimeTypes{$fext});
				}
				elsif ($fid =~ /\.(?:html?|tmpl)$/io)
				{
print STDERR "-chose HTML!\n"  if ($debug);
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'HTML');
				}
				elsif ($fid =~ /\.js$/io)
				{
print STDERR "-chose JavaScript!\n"  if ($debug);
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'Kate::JavaScript');
				}
				elsif ($fid =~ /\.css$/io)
				{
print STDERR "-chose CSS!\n"  if ($debug);
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'Kate::CSS');
				}
				elsif ($fid =~ /\.sh$/io)
				{
print STDERR "-chose Bash!\n"  if ($debug);
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'Bash');
				}
				else
				{
					my ($line1) = split(/\n/o, $indata);
					if ($line1 =~ /\#\!.+perl/o)
					{
						$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
								-syntax => 'Kate::Perl');
print STDERR "-chose Perl based on line 1(#!)!\n"; #  if ($debug);
					}
					elsif ($line1 =~ /\#\!.+sh\s*$/o)
					{
						$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
								-syntax => 'Bash');
print STDERR "-chose Bash based on line 1(#!)!\n"; #  if ($debug);
					}
					else
					{
						my $langModule = &kateExt($fid) || 'None'; 
						$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
								-syntax => $langModule);
print STDERR "-chose (otherwise) $langModule!\n"  if ($debug);
					}
				}
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure('-rules' => undef);
#print STDERR "-??????0- tsw=$textsubwidget= aw=$activeWindow=\n";
#print STDERR "-??????1- tsw=$textsubwidget= aw=$activeWindow= widget=".$textScrolled[$activeWindow]."=\n";
#print STDERR "-??????2- tsw=$textsubwidget= aw=$activeWindow= widget=".$textScrolled[$activeWindow]->Subwidget($textsubwidget)."=\n";
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->highlightPlug;
			}
			$textScrolled[$activeWindow]->insert('end',$indata);
			#NEXT 21 ADDED TO HANDLE LEGACY PC-WRITE "COMMENTS" (MAKE THEM BLUE LIKE PC-WRITE)
			my $srchpos = '1.0';
			my $cnt = 1;
			while (1)
			{
				$srchpos = $textScrolled[$activeWindow]->search(-forwards, -regexp, -count => \$lnoffset, '--', "\x07[^\x07\r]+\x07?", $srchpos, 'end');
				last  if not $srchpos;
				$textScrolled[$activeWindow]->tagAdd("Comment_$cnt", $srchpos, "$srchpos + $lnoffset char");
				$textScrolled[$activeWindow]->tag("configure", "Comment_$cnt", -foreground => 'blue');
				$srchpos = $textScrolled[$activeWindow]->index("$srchpos + $lnoffset char");
				++$cnt;
			}
			$srchpos = '1.0';
			while (1)
			{
				$srchpos = $textScrolled[$activeWindow]->search(-forwards, -regexp, -count => \$lnoffset, '--', "\x02[^\x02\r]+\x02?", $srchpos, 'end');
				last  if not $srchpos;
				$textScrolled[$activeWindow]->tagAdd("Bold_$cnt", $srchpos, "$srchpos + $lnoffset char");
				$textScrolled[$activeWindow]->tag("configure", "Bold_$cnt", -foreground => 'white');
				$srchpos = $textScrolled[$activeWindow]->index("$srchpos + $lnoffset char");
				++$cnt;
			}
		}
		$cmdfile{$activeTab}[$activeWindow] = $fid;
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$fid\"");
		$textScrolled[$activeWindow]->markSet('insert','0.0');
		if (($newsupertext || $AnsiColor) && -r "${fid}.etg" && open (INFID, "${fid}.etg"))
		{
			my ($onoff, $tagtype, $tagindx, %tagStartHash);
			while (<INFID>)
			{
				s/s+$//o;
				($onoff, $tagtype, $tagindx) = split(/\:/o);
				if ($onoff eq '-')
				{
					if ($tagStartHash{$tagtype})
					{
						if ($tagtype =~ /ul$/o)
						{
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype, -underline => 1);
						}
						elsif ($tagtype =~ /bd$/o)
						{
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype, -font => [-weight => "bold" ]);
						}
						elsif (substr($tagtype,4,2) eq 'bg')
						{
							my $color = substr($tagtype,6);
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype,"-background" => $color);
						}
						else
						{
							my $color = substr($tagtype,6);
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype,"-foreground" => $color);
						}
					}
				}
				else
				{
					$tagStartHash{$tagtype} = $tagindx;
				}
			}
			close INFID;
		}
		if (-r "${fid}.emk" && open (INFID, "${fid}.emk"))
		{
			my ($mkName, $mkPosn);
			while (<INFID>)
			{
				chomp;
				($mkName, $mkPosn) = split('=');
				$mkPosn =~ s/\s+$//o;    #FOR SOME REASON, CHOMP NOT WORKIN'?!
				&addMark($mkName, $mkPosn)  if ($mkPosn =~ /^[\d\.]+$/o);
			}
			close INFID;
#			unlink "${fid}.emk"  unless ($v);
		}
		unless ($v)
		{
			#$backupct = &backupFn($fid);
			$backupct = &backupFn($nb ? 'e.before.tmp' : 0);
		}
		$_ = "..Successfully opened file: \"$fid\".";
		unless ($v || $nb)
		{
			$_ .= " backup=$backupct."  if ($backupct =~ /\d/o);
		}
		&setStatus( $_);
		unless ($v)
		{
			if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
			{
				$whichTextWidget->resetUndo;   #FOR SOME REASON SUPERTEXT HATH IT'S OWN METHOD NAMES?!
			}
			else
			{
				eval { $whichTextWidget->ResetUndo; };
			}
		}
		return 1;
	}
	else
	{
		&setStatus("..Could not open file: \"$fid\"!");
		return undef;
	}
}

sub appendfile
{
	my ($fid) = '';

	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => 'Select file to insert:',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 16,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => 0);

	$fid = $fileDialog->Show;
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	return  unless ($fid =~ /\S/o);

	if (open(INFID,$fid))
	{
		binmode INFID;
		$textScrolled[$activeWindow]->markSet('selstartmk','insert');
		$textScrolled[$activeWindow]->markGravity('selstartmk','left');
		$textScrolled[$activeWindow]->markSet('selendmk','insert');
		$textScrolled[$activeWindow]->markGravity('selendmk','right');
		while (<INFID>)
		{
			s/\r\n?/\n/go;
			$textScrolled[$activeWindow]->insert('insert',$_)  unless ($v);
		}
		close INFID;
		$textScrolled[$activeWindow]->tagAdd('sel', 'selstartmk', 'selendmk');
		my ($pos) = $textScrolled[$activeWindow]->index('selstartmk');
		$statusLabel->configure(
				-text => "..Successfully inserted file: \"$fid\" at $pos.");
	}
	else
	{
		&setStatus("..Could not open file: \"$fid\"!");
	}
}

sub writedata
{
	my ($fid) = shift;
	my $opt = shift || 0;
	my $saveopt = shift || 0;
	
#		$msg = "file \"$cmdfile{$activeTab}[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
#				if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
	my ($ffid) = ">$fid";
	#####$ffid = '>'.$ffid  if ($_);   #MAKE APPEND IF SAVING "SELECTED" TEXT.

	#if (open(OUTFID,">$fid"))
	if (open(OUTFID, $ffid))
	{
		&write2file($fid, $opt, $saveopt);
		my (@fidinfo) = stat($fid);          #ADDED 20060601.
		$fileLastUpdated = $fidinfo[8];
		return (0);
	}
	else
	{
		if ($! =~ /Too many open files/o)  #MUST "REPLACE" FILES ON WEBFARM?!
		{
			if (open(OUTFID, ">$hometmp/e.out.tmp"))
			{
				&write2file($fid, $opt, $saveopt);
				#`rm -f $fid`;
				unlink($fid);
				if ($? || $!)
				{
					sleep (1);
					copy("${hometmp}/e.out.tmp", $fid);
					eval { `chmod 777 $hometmp/e.out.tmp $fid`; };
					return (0)  if ($? || $!);
				}
			}
		}
		print "-writedata: could not open $ffid ($!)!\n";
		&setStatus("e:Could not save $fid ($!)!");
		return (1);
	}
}

sub write2file
{
	my ($fid) = shift;
	my $opt = shift || 0;
	my $saveopt = shift || 0;

	binmode OUTFID;
	#$_ = '';
	unless ($opt)
	{
		$_ = $textScrolled[$activeWindow]->getansi('0.0','end')
				if (($newsupertext || $AnsiColor) && $saveopt == 2);
	}
	$_ = $textScrolled[$activeWindow]->get('0.0','end')  unless ($_);
	chomp;
	s/\r\n/\n/go;
	if ($opsysList{$activeTab}[$activeWindow] eq 'DOS')
	{
		s/\n/\r\n/go;
  	}
	elsif ($opsys eq 'Mac')
	{
		s/\n/\r/go;
	}
	print OUTFID;
	close OUTFID;
	&saveTags($fid)  if ($saveopt != 2);
	&saveMarks($fid, $activeWindow)  if ($saveopt == 3 || $savemarks);
	&setStatus("..Edits saved to file: \"$fid\".");
}

sub saveMarks
{
	my $ffid = $_[0] . '.emk';
	my $thiswindow = $_[1];
	my @marks = sort keys %{$markHash{$activeTab}[$thiswindow]};
print STDERR "-saveMarks: aw=$thiswindow= mark0=$marks[0]=\n"  if ($debug);
	my ($m, $mk, $mkIndex);
	if ($#marks >= 0)
	{
		foreach $m (@marks)
		{
			if ($markMenuHash{$activeTab}[$activeWindow]{$m}->{markposn})
			{
				if (open(OUTFID, ">$ffid"))
				{
					foreach $mk (@marks)
					{
#						print OUTFID "$mk=".$markMenuHash{$activeTab}[$activeWindow]{$mk}->{markposn}."\n";
						$mkIndex = $markWidget{$activeTab}[$activeWindow]{$mk}->index($mk);
						print OUTFID "$mk=$mkIndex\n";
					}
					close OUTFID;
				}
				return;
			}
		}
	}
}

sub saveTags
{
	my $fid = shift;

	if ($newsupertext || $AnsiColor)
	{
		my $ffid = $fid . '.etg';
		my @xdump;
		eval { @xdump = $textScrolled[$activeWindow]->dump(-tag, '0.0', 'end'); };
		my $taglist = '';
		my $foundatag = 0;
		for ($i=0;$i<=$#xdump;$i+=3)
		{
			if ($xdump[$i+1] =~ /^ANSI/o)
			{
				$taglist .= (($xdump[$i] eq 'tagon') ? '+' : '-')
						. ':'.$xdump[$i+1].':'.$xdump[$i+2]."\n";
				$foundatag++;
			}
		}
		if ($foundatag && open(OUTFID, ">$ffid"))
		{
			print OUTFID $taglist;
			close OUTFID;
		}
		else
		{
			unlink $ffid;
		}
	}
}

sub newSearch
{
	my ($newsearch) = shift;

	my ($whichTextWidget) = $textScrolled[$activeWindow];
	eval { $whichTextWidget->tagDelete('savesel'); };
	eval { $whichTextWidget->tagAdd('savesel', 'sel.first', 'sel.last'); };
	$srchTextVar = '';
	my ($clipboard);

	eval
	{
		$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
	}
	;
	unless (defined($clipboard))
	{
		eval
		{
			$clipboard = $whichTextWidget->get('foundme.first','foundme.last');
		}
	}
	unless (defined($clipboard) && $clipboard =~ /\S/o)
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		}
		;
	}

	$startattop = 1  if ($newsearch);
	if (Exists($xpopup))
	{
		$MainWin->focus();
print "-4--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$xpopup->destroy;
		$MainWin->raise();
	}
	$xpopup = $MainWin->Toplevel;
	$xpopup->title('Search For:');
	$whichTextWidget->tagDelete('foundme');

	$srchText = $xpopup->JBrowseEntry(
			-label => '',
			-textvariable => \$srchTextVar,
			-choices => \@srchTextChoices,
			-listrelief => 'flat',
			-relief => 'sunken',
			-browsecmd => sub { 
				$srchopts = $srchOptChoices{$srchTextVar}  if (defined($srchOptChoices{$srchTextVar}));
				$srchops ||= '-nocase';
				if (defined($replTextChoices{$srchTextVar}))
				{
					$replText->delete('0','end');
					$replText->insert('end',$replTextChoices{$srchTextVar});	
				}
			},
			-takefocus => 1,
			-browse => 1,
			-noselecttext => 1,
			-deleteitemsok => 1,
			-width  => 38)->pack(
			-padx		=> '2m',
			-side		=> 'top');
	my ($srchLabel) = $xpopup->Label(-text => 'Search for expression');
	$srchText->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$srchText->bind('<Escape>' => sub
		{
			$MainWin->focus();
print "-5--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
			$xpopup->destroy;
			$MainWin->raise();
			eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		}
	);
	$srchLabel->pack(
			-fill	=> 'x');
	$replText = $xpopup->Entry(
			-relief => 'sunken',
			-width  => 40)->pack(
			-padx		=> '2m',
			-side		=> 'top');
	$replText->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$replText->configure(-state => 'disabled')  if ($v);
	my ($replLabel) = $xpopup->Label(-text => 'Replace with expression');
	$replLabel->configure(-fg => $pasteButton->cget('-disabledforeground'))  if ($v);
	$replLabel->pack(
			-fill	=> 'x');

	$srchopts = '-nocase'  if ($newsearch);
	$exactButton = $xpopup->Radiobutton(
			-text   => 'Exact match?',
			-underline => 0,
			-takefocus      => 1,
			-value		=> '-exact',
			-variable=> \$srchopts);
	$exactButton->pack(
			-side   => 'top',
			-pady   => 6);
	$caseButton = $xpopup->Radiobutton(
			-text   => 'Case-insensitive?',
			-underline => 5,
			-takefocus      => 1,
			-value	=> '-nocase',
			-variable=> \$srchopts);
	$caseButton->pack(
			-side   => 'top',
			-pady   => 6);
	$regxButton = $xpopup->Radiobutton(
			-text   => 'Regular-expression?',
			-underline => 0,
			-takefocus      => 1,
			-value	=> '-regexp',
			-variable=> \$srchopts);
	$regxButton->pack(
			-side   => 'top',
			-pady   => 6);

#NEXT 2 LINES PREVENT CORE-DUMPS ON MY BOX!
$_ = `perl -v`;
#$regxButton->configure(-state => 'disabled')  if (/5\.8\.0/);
	my ($srchdirFrame) = $xpopup->Frame;
	$srchdirFrame->pack(-side => 'top', -fill => 'x');
	$srchwards = 1  if ($newsearch);
	$backButton = $srchdirFrame->Radiobutton(
			-text   => 'Backwards?',
			-underline => 0,
			-takefocus      => 1,
			-value	=> 0,
			-variable=> \$srchwards);
	$backButton->pack(
			-side   => 'left',
			-padx 	=> 12,
			-pady   => 6);
	$topCbtn = $srchdirFrame->Checkbutton(
			-text   => 'Start at top?',
			-underline => 0,
			-variable=> \$startattop);
	$topCbtn->pack(
			-side   => 'left',
			-padx 	 => 12,
			-pady   => 6);
	$forwButton = $srchdirFrame->Radiobutton(
			-text   => 'Forwards?',
			-underline => 0,
			-takefocus	=> 1,
			-value  => 1,
			-variable=> \$srchwards);
	$forwButton->pack(
			-side   => 'left',
			-padx 	 => 12,
			-pady   => 6);

	my $btnframe2 = $xpopup->Frame;
	$btnframe2->pack(-side => 'bottom', -fill => 'x');
	my $btnframe = $xpopup->Frame;
	$btnframe->pack(-side => 'bottom', -fill => 'x');

	my $okButton = $btnframe->Button(
			-pady => 2,
			-text => 'Ok',
			-underline => 0,
			#-command => [\&doSearch,1]);
			-command => sub { &updateSearchHistory(); &doSearch(1)});
	$okButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $gsrButton = $btnframe->Button(
			-pady => 2,
			-text => 'Global',
			-underline => 0,
			-command => sub { &updateSearchHistory(); &GlobalSrchRep($whichTextWidget)});
	$gsrButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $pasteButton = $btnframe->Button(
			-pady => 2,
			-text => 'Paste',
			-underline => 0,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$clipboard); $whichTextWidget->tagDelete('savesel') }  if (defined($clipboard));
		eval {$activewidget->tagRemove('sel','0.0','end');};
	}
	);
	$pasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$pasteButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $cbpasteButton = $btnframe->Button(
			-pady => 2,
			-text => 'CB Paste',
			-underline => 1,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$MainWin->SelectionGet(-selection => 'CLIPBOARD'));};
		eval {$activewidget->tagRemove('sel','0.0','end');};
	}
	);
	$cbpasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$cbpasteButton->pack(-side=>'left', -expand=>1, -pady => 6);

	my $dbugButton = $btnframe->Button(
			-pady => 2,
			-text => 'd-bug',
			-underline => 0,
			-command => sub
	{
		if ($srchTextVar)
		{
			$replText->delete('0','end');
			$replText->insert('end','\#$1');	
		}
		else
		{
			$srchTextVar = ($cmdfile{$activeTab}[$activeWindow] =~ /\.(?:js|.*ht.+)$/io) ? '^(alert)' : '^(print|for)';
		}
		$srchText->icursor(length($srchTextVar));
		$srchopts = '-regexp';
	}
	)->pack(-side=>'left', -expand=>1, -pady => 6);

	my $revButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Rev. S & R',
			-command => \&revsrtext);
	$revButton->pack(-side=>'left', -expand=>1, -pady => 6);
	$revButton->configure(-state => 'disabled')  if ($v);

	my ($subButton);
	$subButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Sub/Fn',
			-command => sub
	{
		$srchTextVar = ($cmdfile{$activeTab}[$activeWindow] =~ /\.(?:js|.*ht.+)$/io) ? 'function ' : 'sub ';
		$srchText->icursor(length($srchTextVar));
	}
	)->pack(-side=>'left', -expand=>1, -pady => 6);

	my $canButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Cancel',
			-underline => 0,
			-command => sub
	{
		$MainWin->focus();
print "-6--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$xpopup->destroy;
		$MainWin->raise();
		eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
	}
	);
	$canButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $clearButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Clear',
			-underline => 1,
			-command => sub { $srchTextVar = ''; $replText->delete('0','end');});
	$clearButton->pack(-side=>'left', -expand=>1, -pady => 6);
	$xpopup->bind('<Escape>'        => [$canButton	=> Invoke]);

	$srchText->bind('<Return>'        => [$okButton	=> 'Invoke']);
	$replText->bind('<Return>'        => [$okButton	=> 'Invoke']);
	$xpopup->bind('<Escape>'        => [$canButton	=> 'Invoke']);

	$srchpos = '1.0';
	$lnoffset = 0;

	unless ($newsearch || $srchstr le ' ')
	{
		$srchTextVar .= $srchstr;
	}
	$replText->insert('end',$replstr)  unless ($newsearch || $replstr le ' ');
	$xpopup->focus();
	$srchText->focus();
}

sub doSearch
{
	my ($newsearch) = shift;

	my $whichTextWidget = $textScrolled[$activeWindow];

	eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); }
			if (Exists($xpopup));
	$srchwards = shift  if (@_);
	if ($newsearch)
	{
		for ($i=1;$i<=$tagcnt;$i++)
		{
			$whichTextWidget->tagDelete("foundme$i");
		}
		$tagcnt = 0;
	}
	$findMenubtn->entryconfigure('Search Again', -state => 'normal');
	$findMenubtn->entryconfigure('Search Forward >', -state => 'normal');
	$findMenubtn->entryconfigure('Search Backward <', -state => 'normal');
	$findMenubtn->entryconfigure('Modify search', -state => 'normal');
	$againButton->configure(-state => 'normal');
	$bkagainButton->configure(-state => 'normal');
	if ($newsearch == 2)   #START EDITOR AT THIS POSITION!
	{
		$srchstr = $s;
		$srchopts = '-exact';
		$srchopts = '-nocase'  if ($srchstr =~ s#/i$##o);
		$srchwards = 1;
	}
	else
	{
		$srchstr = $srchTextVar  if ($newsearch);
		eval { $replstr = $replText->get }  if ($newsearch);  #PRODUCES ERROR SOMETIMES W/O EVEL?!?!?!
		if (Exists($xpopup))
		{
			$MainWin->focus();
print "-7--AW=$activeWindow= AT== scr0=$textScrolled[0]=\n"  if ($debug);
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
			$whichTextWidget->Subwidget($textsubwidget)->focus();
			$xpopup->destroy;
			$MainWin->raise();
		}
	}
	$srchpos = '0.0'  if ($whichTextWidget->index('insert') >= $whichTextWidget->index('end') - 1);
	$lnoffset = !$newsearch;
	$srchpos = $whichTextWidget->index('insert')  unless ($newsearch && $startattop);
	$startattop = 0;
	if ($srchwards)
	{
		$srchpos = $whichTextWidget->search(-forwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, 'end');
	}
	else
	{
		my ($l) = length($srchstr) || 0;
		$srchpos = $whichTextWidget->index("insert - $l char")  if ($l > 0);
		$srchpos = $whichTextWidget->search(-backwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, '0.0');
	}
	if ($srchpos)
	{
		&setStatus("..Found \"$srchstr\" at position $srchpos");
		$whichTextWidget->tagDelete('foundme');
#		eval { $whichTextWidget->tagRemove('sel','0.0','end'); };  #REMOVED 20080426; ADDED 20080411
		$whichTextWidget->markSet('anchor', $srchpos);
#		$whichTextWidget->tagAdd('sel', $srchpos, "$srchpos + $lnoffset char");  #REMOVED 20080426; ADDED 20080411
		$whichTextWidget->tagAdd('foundme', $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure('foundme',
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'yellow',
				-foreground     => 'black');
		$whichTextWidget->see($srchpos);
		$srchpos = $whichTextWidget->index("$srchpos + $lnoffset char");
		$whichTextWidget->markSet('_prev','insert');
		$whichTextWidget->markSet('insert',$srchpos);
		$srchpos = $whichTextWidget->index('foundme.first')  unless ($srchwards);
		my ($replstrx) = $replstr;
		if ($replstr =~ /\S/o and !$v)
		{
			#$replstrx = ''  if ($replstr eq "\'\'");  #CHGD. TO NEXT 20050331.
			$replstrx = ''  if ($replstr eq "``");  #TREAT `` AS EMPTY STR!
			$replDialog->configure(
					-text => "Replace\n\"$srchstr\"\nwith\n\"$replstrx\"?");
			$usrres = $replDialog->Show($showgrabopt);
			if ($usrres eq $Yes)
			{
				$chgstr = $whichTextWidget->get('foundme.first','foundme.last');
				if ($srchopts eq '-regexp')
				{
					$_ = $replstrx;   #ADDED NEXT 7 20010924.
					s/\:\#([+-]\d+)?/
							my ($offset) = $1;
							my $str = $tagcnt+($offset);
							"$str"
					/eg;
					$chgstr =~ s/$srchstr/eval "return \"$replstrx\""/egs;
				}
				elsif ($srchopts eq '-nocase')
				{
					$chgstr =~ s/\Q$srchstr\E/$replstrx/eigs;
				}
				else
				{
					$chgstr =~ s/\Q$srchstr\E/$replstrx/egs;
				}
				$whichTextWidget->delete('foundme.first','foundme.last');
				$whichTextWidget->insert('insert',$chgstr);
				$whichTextWidget->tagDelete('foundme');
				$lnoffset = length($chgstr);
				++$tagcnt;
				$whichTextWidget->tagAdd("foundme$tagcnt", "insert - $lnoffset char", "insert");
				$whichTextWidget->tagConfigure("foundme$tagcnt",
						-relief => 'raised',
						-borderwidth => 1,
						-background  => 'green',
						-foreground     => 'black');
			}
		}
	}	
	else
	{
		&setStatus("..Did not find \"$srchstr\".");
	}
}

sub clearSearch
{
	for ($i=1;$i<=$tagcnt;$i++)
	{
		$textScrolled[$activeWindow]->tagDelete("foundme$i");
	}
	$tagcnt = 0;
	eval {$textScrolled[$activeWindow]->tagDelete("foundme"); };
}

sub revsrtext
{
	my ($s) = $srchTextVar;
	my ($r) = $replText->get;
	$srchTextVar = $r;
	$replText->delete('0','end');
	$replText->insert('end',$s);
}

sub doIndent
{
	my ($doright) = shift;
	my $standAloneBlock = shift;
	&beginUndoBlock($textScrolled[$activeWindow])  if ($standAloneBlock);
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	my $indentStr = $notabs ? $tspaces : "\t";

	$textScrolled[$activeWindow]->markSet('selstart','sel.first linestart - 2 char');
	if ($lastpos =~ /\.0$/o)
	{
		$textScrolled[$activeWindow]->markSet('selend','sel.last - 1 char');
	}
	else
	{
		$textScrolled[$activeWindow]->markSet('selend','sel.last lineend');
	}
	$textScrolled[$activeWindow]->markSet('_prev','insert');
	$textScrolled[$activeWindow]->markSet('insert','selend');
	$clipboard = $textScrolled[$activeWindow]->get('sel.first linestart - 1 char','selend');
	if ($doright == 1)       #SHIFT ALL LINES RIGHT 1 TAB-STOP.
	{
		my @l = split(/\n/o, $clipboard, -1);
		for (my $i=0;$i<=$#l;$i++)
		{
			$l[$i] = $indentStr . $l[$i]  unless ($l[$i] !~ /\S/o || ($l[$i] =~ /^(?:\#.*|\w+(?:\:\s*\;\s*)?)$/o && $l[$i] !~ /^else\s*$/io));
		}
		$clipboard = join("\n", @l);
	}
	else                     #SHIFT ALL LINES LEFT 1 TAB-STOP OR 3 SPACES.
	{
		$clipboard =~ s/\n(\t|$tspaces)/\n/g;
	}
	$textScrolled[$activeWindow]->delete('sel.first linestart - 1 char','selend');
	$textScrolled[$activeWindow]->insert('insert',$clipboard);
	$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend + 1 char');
	$textScrolled[$activeWindow]->markSet('insert', 'sel.first');
	&endUndoBlock($textScrolled[$activeWindow])  if ($standAloneBlock);
}

sub setcase
{
	my ($whichflag) = shift;
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	eval
	{
		$textScrolled[$activeWindow]->markSet('selstart','sel.first');
		$textScrolled[$activeWindow]->markSet('selend','sel.last');
		$textScrolled[$activeWindow]->markSet('_prev','insert');
		$textScrolled[$activeWindow]->markSet('insert','selend');
		$clipboard = $textScrolled[$activeWindow]->get('sel.first - 1 char','selend');
		if ($whichflag)    #CONVERT ALL TEXT TO LOWER-CASE.
		{
			$clipboard =~ tr/A-Z/a-z/;
		}
		else               #CONVERT ALL TEXT TO UPPER-CASE.
		{
			$clipboard =~ tr/a-z/A-Z/;
		}
		$textScrolled[$activeWindow]->delete('sel.first - 1 char','selend');
		$textScrolled[$activeWindow]->insert('insert',$clipboard);
		my ($l) = length($clipboard) - 1;
		$textScrolled[$activeWindow]->tagAdd('sel',"selend - $l char",'selend');
	}
}

sub gotoErr
{
	my ($errline) = shift;

	my ($errsel) = undef;
	eval
	{
		$errsel = $MainWin->SelectionGet(-selection => 'PRIMARY');
	}
	;
	$errline = $errsel  if ($errsel);
	$errline =~ s/\D//go;
	&gotoMark($textScrolled[$activeWindow], $errline);
}

sub doSave
{
	my ($mytitle) = "File to save results:";
	my ($create) = 1;
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title =>$mytitle,
			-Path => $startpath,
			-History => (defined $histmax) ? $histmax : 16,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => $create);

	my ($myfile) = $fileDialog->Show(-Horiz=>0);
	&fixAfterStep()  if ($Steppin);
   	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	if ($myfile =~ /\S/o && open(OUTFID, ">$myfile"))
	{
		binmode OUTFID;
		$_ = $text2Scrolled->get('0.0','end');
		chomp;
		s/\r\n/\n/go;
		if ($opsys eq 'DOS')
		{
			s/\n/\r\n/go;
	  	}
		elsif ($opsys eq 'Mac')
		{
			s/\n/\r/go;
		}
		print OUTFID;
		close OUTFID;
		&setStatus("..Results saved to file: \"$myfile\".");
		return (0);
	}
	else
	{
		&setStatus("e:COULD NOT SAVE TO \"$myfile\"!");
		print "e:COULD NOT SAVE RESULTS TO \"$myfile\"!\n";
		return (1);
	}
}

sub savexFn
{
	&exitFn($Yes);
}

sub clearMarks
{
#print "---CLEARMARKS--- AW=$activeWindow= AT=$activeTab=\n";
	my $lastMenuItem = $markMenubtn->menu->index('end');
#print "----last=$lastMenuItem=\n";
	$markMenubtn->menu->delete($markMenuTop+1,'end')  if ($lastMenuItem > $markMenuTop);
	foreach my $i (keys %{$markHash{$activeTab}[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
	{
#print "--------DELETING MARK($i) for $activeTab!\n";
		delete $markHash{$activeTab}[$activeWindow]->{$i};
		delete $markWidget{$activeTab}[$activeWindow]{$i};
		$markMenuIndex{$activeTab}[$activeWindow][$markMenuHash{$activeTab}[$activeWindow]{$i}->{index}] = 0;
		delete $markMenuHash{$activeTab}[$activeWindow]{$i};
	}
	for (my $i=0;$i<=$#{$markMenuIndex{$activeTab}[$activeWindow]};$i++)
	{
		if ($markMenuIndex{$activeTab}[$activeWindow][$i] && $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]})
		{
			$markMenubtn->command(
					-label => $markMenuIndex{$activeTab}[$activeWindow][$i],
					-underline => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{underline} || '0',
					-command => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{command});
		}
	}
	$marklist{$activeTab}[$activeWindow] = ':insert:sel:';
}

sub resetMarks
{
#print "---RESETMARKS---\n";
	return unless (defined $markMenubtn);
	my $lastMenuItem = $markMenubtn->menu->index('end');
	$markMenubtn->menu->delete($markMenuTop+1,'end')  if ($lastMenuItem > $markMenuTop);
	for (my $i=0;$i<=$#{$markMenuIndex{$activeTab}[$activeWindow]};$i++)
	{
		if ($markMenuIndex{$activeTab}[$activeWindow][$i] && $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]})
		{
			$markMenubtn->command(
					-label => $markMenuIndex{$activeTab}[$activeWindow][$i],
					-underline => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{underline} || '0',
					-command => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{command});
		}
	}
}

sub addMark
{
	$intext = shift;
	$mkPosn = shift || 'insert';
	&gettext("Mark Name:",20,'t',2)  unless ($intext);
	$intext = '_Bookmark'  unless ($intext =~ /^[_a-zA-Z0-9]/o);
#print "--addMark:  tab=$activeTab= next=".$markNextIndex{$activeTab}[$activeWindow]."=\n";
	unless ($intext eq  '*cancel*')
	{
		unless ($intext !~ /\S/o || $marklist{$activeTab}[$activeWindow] =~ /\:$intext\:/)
		{
			($intext,$ul) = split(/\,/o, $intext);
			$ul = 0  unless ($ul =~ /^\d+$/o);
			$ul = 4  if (!$ul && !$filetype && $intext =~ /^sub /o);
			#EVAL SO THAT "$intext" IS SET STATICALLY!
			$markWidget{$activeTab}[$activeWindow]{$intext} = $textScrolled[$activeWindow];
			#########eval { $markMenubtn->menu->delete($intext); };
			$activeWindow = 0  unless ($activeWindow =~ /\d/o);
			$evalstr = "
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{index} = \$markNextIndex{\"$activeTab\"}[$activeWindow];
					\$markMenuIndex{\"$activeTab\"}[$activeWindow][\$markNextIndex{\"$activeTab\"}[$activeWindow]] = \"$intext\";
					\$markNextIndex{\"$activeTab\"}[$activeWindow]++;
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{underline} = \$ul || '0';
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{tab} = \"$activeTab\";
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{command} = sub
					{
						\$tabbedFrame->raise(\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{tab})  unless (\$nobrowsetabs);
						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->markSet('_prev','insert');
						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->markSet('insert',\"$intext\");
						my (\$gotopos) = \$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->index('insert');

						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->see(\$gotopos);
						\&setStatus(\"Cursor now at \$gotopos.\");
						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->focus;
					};
					\$markMenubtn->command(
						-label => '$intext',
						-underline => \$ul,
						-command => \$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{command}
					);
			";
#print "-???- hash=".$markMenuHash{$activeTab}[$activeWindow]{$intext}."= act=$activeTab= intext=$intext= eval=$evalstr=\n";
			eval $evalstr  unless ($markMenuHash{$activeTab}[$activeWindow]{$intext});
#print "-!!!- eval result=$@=\n";
			$marklist{$activeTab}[$activeWindow] .= ':' . $intext . ':';
		}
#print "-*****- done adding mark!\n";
		$textScrolled[$activeWindow]->markSet("$intext",$mkPosn);
		delete $markHash{$activeTab}[($activeWindow ? 0 : 1)]->{$intext};
		$marklist{$activeTab}[($activeWindow ? 0 : 1)] =~ s/\Q\:$intext\E\://;
		$markHash{$activeTab}[$activeWindow]->{$intext} = $intext;
		my ($markpos) = $textScrolled[$activeWindow]->index($mkPosn);
		$markMenuHash{$activeTab}[$activeWindow]{$intext}->{markposn} = $markpos;
		&setStatus("Mark \"$intext\" set to $markpos.");
	}
#print "-*****- leaving addmark!\n";
}

sub gettext
{
	my ($header,$sz,$typ,$mk,$mylist,$preload,$csr) = @_;

	my ($clipboard);
	$inlist = '';

	if ($mylist != 1)   #1ST TRY PRIMARY SELECTION.
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
		}
		;
		unless (length($clipboard) > 0)  #ADDED 20080426 - NEXT TRY "FOUND" TEXT (HANDY FOR MARKS)!
		{
			eval
			{
				$clipboard = $textScrolled[$activeWindow]->get('foundme.first','foundme.last');
			}
		}
	}
	unless (length($clipboard) > 0)  #LAST, TRY THE CLIPBOARD.
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		}
		;
	}

	$textPopup = $MainWin->Toplevel;
	$textPopup->title($header);
	my $getText = $textPopup->Entry(
			-relief => 'sunken',
			-width  => $sz);
	$getText->insert('end',$intext)  if ($preload);
	$getText->icursor($getText->index($csr))  if ($csr);
	$getText->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$getText->bind('<Alt-v>' => sub
	{
		eval
		{
			$curTextWidget->insert('insert',
					$MainWin->SelectionGet(-selection => 'PRIMARY'));
		}
	}
	);

	if ($typ eq 'p')
	{
		$getText->configure(
				-show   => '*');
	}

	if ($mylist && $mylist != 1)
	{
		$listFrame = $textPopup->Frame;
		$chooseOption = $listFrame->JOptionmenu(
				-textvariable => \$inlist,
				-command => [\&dobuttons, $textPopup, $getText, 0],
				-highlightthickness => 2,
				-takefocus => 1,
				-options => $mylist,
		)->pack;
	}
	my $btnframe = $textPopup->Frame;

	my $okButton = $btnframe->Button(
			-padx => 12,
			-pady =>  6,
			-text => 'Ok',
			-underline      => 0,
			-command => [\&dobuttons, $textPopup, $getText, 0]);
	$okButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');

	if ($mk == 1)
	{
		my $prvbutton = $btnframe->Button(
				-padx => 12,
				-pady =>  6,
				-text => 'Back',
				-underline      => 0,
				-command => [\&dobuttons, $textPopup,$getText, 2]);
		$prvbutton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	}
	elsif ($mk == 2)
	{
		my $prvbutton = $btnframe->Button(
				-padx => 12,
				-pady =>  6,
				-text => 'Line',
				-underline      => 0,
				-command => sub
		{
			$curTextWidget->insert('insert',(
					$textScrolled[$activeWindow]->index('insert')));
		}
		);
		$prvbutton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	}

	my $pasteButton = $btnframe->Button(
			-pady => 6,
			-text => 'Paste',
			-underline => 0,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$clipboard);}  if (defined($clipboard));
	}
	);
	$pasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$pasteButton->pack(-side=>'left', -expand=>1, -pady=> '2m');

	my $canButton = $btnframe->Button(
			-padx => 12,
			-pady =>  6,
			-text => 'Cancel',
			-underline      => 0,
			-command => [\&dobuttons, $textPopup,$getText, 1]);
	$canButton->pack(-side=>'right', -expand=>1, -padx=>'2m', -pady=>
	'2m');

	my ($btnframe2, $insButton, $sel0Button, $sel1Button);
	if ($mk == 1)
	{
		$markSelected = '';
		$btnframe2 = $textPopup->Frame;

		$insButton = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'Insert',
				-underline      => 0,
				-command => [\&dobuttons, $textPopup, $getText, 3]);
		$insButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		$sel0Button = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'Sel.First',
				-underline      => 4,
				-command => [\&dobuttons, $textPopup, $getText, 4]);
		$sel0Button->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		$sel1Button = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'Sel.Last',
				-underline      => 4,
				-command => [\&dobuttons, $textPopup, $getText, 5]);
		$sel1Button->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		$endButton = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'End',
				-underline      => 0,
				-command => [\&dobuttons, $textPopup, $getText, 6]);
		$endButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		my @markChoices = ('_prev',split(/\:+/o, substr($marklist{$activeTab}[$activeWindow],13)));
		$markList = $textPopup->JBrowseEntry(
				-state => 'readonly',
				-label => 'Select to mark:',
				-choices => \@markChoices,
				-textvariable => \$markSelected,
				-browsecmd => [\&select2Mark]
				);
	}
	$getText->pack(
			-padx   => 12,
			-pady   => 12,
			-side   => 'top');
				#-expand => 'yes',
				#-fill   => 'x');
	$listFrame->pack  if ($mylist && $mylist != 1);
	$markList->pack(-side => 'bottom', -fill => 'x')  if ($mk == 1);
	$btnframe2->pack(-side => 'bottom', -fill => 'x')  if ($mk == 1);
	$btnframe->pack(-side => 'bottom', -fill => 'x');
	$getText->bind('<Return>'       => [$okButton => "Invoke"]);
	$getText->bind('<Escape>'       => [$canButton => "Invoke"]);
	$textPopup->focus();
	$getText->focus();
	$textPopup->waitWindow;  #WAIT HERE FOR USER RESPONSE!!!
}

sub select2Mark
{
	my $start = $textScrolled[$activeWindow]->index('insert');
	my $end = $textScrolled[$activeWindow]->index($markSelected);
	($end > $start) ? $textScrolled[$activeWindow]->tagAdd('sel', 'insert', $markSelected)
			: $textScrolled[$activeWindow]->tagAdd('sel', $markSelected, 'insert');
	$MainWin->focus();
print "-8--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	eval { $textPopup->destroy; };
	$MainWin->raise();
	$textScrolled[$activeWindow]->markSet('_prev', $start);
	$textScrolled[$activeWindow]->markSet('insert', $end);
	$textScrolled[$activeWindow]->see('insert');
	&setStatus( "Cursor now at $end.");
	$intext = '*cancel*';   #CANCEL DOGOTO (WE'RE THERE).
}

sub dobuttons
{
	($xPopup, $xText, $abort) = @_;

	if ($abort == 1)
	{
		$intext = '*cancel*';
	}
	elsif ($abort == 2)
	{
		$intext = '_prev';
	}
	elsif ($abort == 3)  #GOTO 'INSERT' CURSOR.
	{
		$intext = $textScrolled[$activeWindow]->index('insert');
	}
	elsif ($abort == 4)  #GOTO 'SEL.START'.
	{
		$intext = '*cancel';
		eval {$intext = $textScrolled[$activeWindow]->index('sel.first'); };
		$intext ||= '*cancel*';
	}
	elsif ($abort == 5)  #GOTO 'SEL.END'.
	{
		$intext = '*cancel*';
		eval {$intext = $textScrolled[$activeWindow]->index('sel.last'); };

		$intext ||= '*cancel*';
	}
	elsif ($abort == 6)  #GOTO 'END'.
	{
		$intext = $textScrolled[$activeWindow]->index('end');
	}
	else
	{
		$intext = $xText->get;
	}
	$MainWin->focus();
print "-9--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$xPopup->destroy;
	$MainWin->raise();
}

sub gotoMark
{
	my ($self,$intext) = @_;

	$intext .= '.0'  if ($intext =~ /^\d+$/o);
	eval 
	{
		if ($markWidget{$activeTab}[$activeWindow]{$intext})
		{
			$markWidget{$activeTab}[$activeWindow]{$intext}->focus;
			$markWidget{$activeTab}[$activeWindow]{$intext}->markSet('_xprev','_prev')  if ($intext eq '_prev');
			$markWidget{$activeTab}[$activeWindow]{$intext}->markSet('_prev','insert');
			$intext = '_xprev'  if ($intext eq '_prev');
			$markWidget{$activeTab}[$activeWindow]{$intext}->markSet('insert',$intext);
			my ($gotopos) = $markWidget{$activeTab}[$activeWindow]{$intext}->index('insert');

			$markWidget{$activeTab}[$activeWindow]{$intext}->see($gotopos);
		}
		else
		{
			$textScrolled[$activeWindow]->focus;
			$textScrolled[$activeWindow]->markSet('_xprev','_prev')  if ($intext eq '_prev');
			$textScrolled[$activeWindow]->markSet('_prev','insert');
			$intext = '_xprev'  if ($intext eq '_prev');
			$textScrolled[$activeWindow]->markSet('insert',$intext);
			my ($gotopos) = $textScrolled[$activeWindow]->index('insert');

			$textScrolled[$activeWindow]->see($gotopos);
		}
		$gotopos = $textScrolled[$activeWindow]->index('insert')
				unless ($gotopos =~ /\S/o);
		&setStatus("Cursor now at $gotopos.");
	}
}

sub doGoto
{
	&gettext("Go To (line#.col#):",20,'t',1);
	unless ($intext eq  '*cancel*')
	{
		$intext = '0'  unless ($intext =~ /\S/o);
		$intext .= '0'   if ($intext =~ /^\d+\.$/o);
		if ($intext =~ /^\s*[\+\-]/o)
		{
			$intext =~ s/\..*$//o;
			eval
			{
				$textScrolled[$activeWindow]->markSet('_prev','insert');
				$textScrolled[$activeWindow]->markSet('insert',"insert $intext lines");
			}
			;
		}
		else
		{
			$intext .= '.0'  if ($intext =~ /^\d+$/o);
			eval
			{
				$textScrolled[$activeWindow]->markSet('_xprev','_prev')  if ($intext eq '_prev');
				$textScrolled[$activeWindow]->markSet('_prev','insert');
				$intext = '_xprev'  if ($intext eq '_prev');
				$textScrolled[$activeWindow]->markSet('insert',$intext);
			}
			;
		}
		my $gotopos = $textScrolled[$activeWindow]->index('insert');
		$textScrolled[$activeWindow]->see('insert');
		&setStatus("Cursor now at $gotopos.");
	}		
}

sub GlobalSrchRep
{
	my ($whichTextWidget) = shift;
	my ($markAllMatches) = shift || 0;

	my ($wholething) = undef;

	eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
	$findMenubtn->entryconfigure('Search Again', -state => 'normal');
	$findMenubtn->entryconfigure('Search Forward >', -state => 'normal');
	$findMenubtn->entryconfigure('Search Backward <', -state => 'normal');
	$findMenubtn->entryconfigure('Modify search', -state => 'normal');
	$srchstr = $srchTextVar;
	$replstr = '';
	eval { $replstr = (defined $replText) ? $replText->get : ''; };
	$MainWin->focus();
print "-10--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$xpopup->destroy  if (Exists($xpopup));
	$MainWin->raise();
	$againButton->configure(-state => 'normal');
	$bkagainButton->configure(-state => 'normal');
	for ($i=1;$i<=$tagcnt;$i++)
	{
		$whichTextWidget->tagDelete("foundme$i");
	}
	$tagcnt = 0;

	eval
	{
		$wholething = $whichTextWidget->get('sel.first','sel.last');
		$selstart = $whichTextWidget->index('sel.first');
		$selend = $whichTextWidget->index('sel.last');
	}
	;
	unless (defined($wholething))
	{
		#$wholething = $whichTextWidget->get('0.0','end');
		$selstart = '0.0';
		$selend = $whichTextWidget->index('end');
		if (length($replstr))
		{
			$replDialog->configure(
					-text => "Replace\n\"$srchstr\"\nwith\n\"$replstr\"\nin Entire file?");
			$usrres = $replDialog->Show();
			return (1)  unless ($usrres eq $Yes);
		}
	}
	$whichTextWidget->markSet('selstartmk',$selstart);
	$whichTextWidget->markSet('selendmk',$selend);

	my ($replstrx) = $replstr;
	$replstrx = ''  if ($replstr eq '``');  #TREAT '' AS EMPTY STR!
	$srchpos = $selstart;
	&beginUndoBlock($whichTextWidget);
	while (1)
	{
		$srchpos = $whichTextWidget->search(-forwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, 'end');
		last  if not $srchpos;
		$selend = $whichTextWidget->index('selendmk');
		last  if ($srchpos > $selend);
		$whichTextWidget->markSet('insert',$srchpos);
		$whichTextWidget->see($srchpos);
		$whichTextWidget->tagDelete('foundme');
		$whichTextWidget->tagAdd('foundme', $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure('foundme',
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'yellow',
				-foreground     => 'black');
		$chgstr = $whichTextWidget->get('foundme.first','foundme.last');
		&addMark($chgstr)  if ($markAllMatches);
		if (length($replstr))
		{
			if ($srchopts eq '-regexp')
			{
				$_ = $replstrx;   #ADDED NEXT 7 20010924.
				s/\:\#([+-]\d+)?/
						my ($offset) = $1;
						my $str = $tagcnt+($offset);
						"$str"
				/eg;
				$chgstr =~ s/$srchstr/eval "return \"$replstrx\""/egs;
			}
			elsif ($srchopts eq '-nocase')
			{
				$chgstr =~ s/\Q$srchstr\E/$replstrx/eigs;
			}
			else
			{
				$chgstr =~ s/\Q$srchstr\E/$replstrx/egs;
			}
		}
		$whichTextWidget->delete('foundme.first','foundme.last');
		$whichTextWidget->insert('insert',$chgstr);
		$whichTextWidget->tagDelete('foundme');
		$lnoffset = length($chgstr);
		++$tagcnt;
		$whichTextWidget->tagAdd("foundme$tagcnt", $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure("foundme$tagcnt",
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'green',
				-foreground     => 'black');
		$srchpos = $whichTextWidget->index("$srchpos + $lnoffset char");
	}
	&endUndoBlock($whichTextWidget);
	&setStatus( "..$tagcnt matches of \"$srchstr\" found/changed!");
	$whichTextWidget->tagAdd('sel', 'selstartmk', 'selendmk');

}

sub shocoords
{
	my ($calledbymouse) = shift;
#	$text1Text->SUPER::mouseSelectAutoScanStop;    #ADDED FOR SUPERTEXT!
	$whichTextWidget->mouseSelectAutoScanStop  if ($SuperText && $calledbymouse && !$v);
	my ($gotopos) = $textScrolled[$activeWindow]->index('insert');
	$textScrolled[$activeWindow]->see($gotopos);
	&setStatus( $gotopos);
}

sub setwrap
{
	my $wrap = shift || 'none';
	$whichTextWidget->configure(-wrap => $wrap);
}

sub print_couples
{
	my $w = shift;

	my $s=$w->cget('-matchingcouples');
	print (defined $s ? $s :'undef');
	print "\n";
}

sub showlength
{
	$clipboard = '';
	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	$clipboard = $textScrolled[$activeWindow]->get('0.0','end')  unless ($clipboard);
	&setStatus( 'Length = '.length($clipboard));
}

sub showSum
{
	$clipboard = '';
	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	$clipboard = $textScrolled[$activeWindow]->get('0.0','end')  unless ($clipboard);
	my @l = split(/\n/o, $clipboard, -1);
	my $columncnt = 0;
	my @sums = ();
	my $columnsnotequal = 0;
	for (my $i=0;$i<=$#l;$i++)
	{
		@numbers = ();
		$j = 0;
		while ($l[$i] =~ s/([\d\+\-\.]+)//o)
		{
			$sums[$j++] += $1;
		}
		if ($columncnt != $j)
		{
			$columnsnotequal = $i  if ($columncnt && $j);
			$columncnt = $j  if ($columncnt < $j);
		}
	}
	$_ = "\tTOTAL:  \t" . join("\t", @sums) . "\n";
	$textScrolled[$activeWindow]->markSet('insert','end');
	eval { $textScrolled[$activeWindow]->markSet('insert','sel.last'); };
	$textScrolled[$activeWindow]->insert('insert',$_);
	&setStatus( 
			"w:No. of Columns NOT EQUAL at row: $columnsnotequal, right-padded w/zeros!")
		if ($columnsnotequal);
}

sub setFont
{
	my ($myfont) = shift;

	$fixedfont = $fixedfonts[$myfont] || $fixedfonts[1];
	
	$whichTextWidget->configure(-font => $fixedfont);
}

sub setTag
{
	my ($fg) = shift;
	my $selstart;
	eval { $selstart = $textScrolled[$activeWindow]->index('sel.first') or '0.0'; };
	$selstart ||= '0.0';
	my $selend;
	eval { $selend = $textScrolled[$activeWindow]->index('sel.last') or 'end'; };
	$selend ||= 'end';

	if ($fg eq 'clear')
	{
		my @xdump = $textScrolled[$activeWindow]->dump(-tag, $selstart, $selend);
		for ($i=0;$i<=$#xdump;$i+=3)
		{
			if ($xdump[$i] eq 'tagon')
			{
				if ($xdump[$i+1] =~ /^ANSI/o)
				{
					$textScrolled[$activeWindow]->tagRemove($xdump[$i+1], $selstart, $selend);
				}
			}
		}
	}
	elsif ($fg eq 'ul')
	{
		$textScrolled[$activeWindow]->tagAdd("ANSIul", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSIul", -underline => 1);
	}
	elsif ($fg eq 'bd')
	{
		$textScrolled[$activeWindow]->tagAdd("ANSIbd", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSIbd", -font => [-weight => "bold" ]);
	}
	elsif (substr($fg,0,1) eq 'b')
	{
		my $color = substr($fg,2);
		$textScrolled[$activeWindow]->tagAdd("ANSI$fg", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSI$fg","-background" => $color);
	}
	else
	{
		my $color = substr($fg,2);
		$textScrolled[$activeWindow]->tagAdd("ANSI$fg", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSI$fg","-foreground" => $color);
	}
}

sub setTheme
{
	my ($bg, $fg, $c, $font);
	my $oldfg = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-foreground');
	my $oldbg = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-background');
	my ($fgsame, $bgsame);
	$foreground = 0;
	eval $_[0];
	$fgsame = 1  if ($fg =~ s/same//io);
	$bgsame = 1  if ($bg =~ s/same//io);
	my $fgisblack;
	$fgisblack = 1  if ($fg =~ /black/io); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!
	$c = ''  if ($c =~ /same/io);
	if ($c =~ /default/io)
	{
		eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
		my $c0;
		$c0 = $MainWin->optionGet('tkVpalette','*')  if ($v);
		$c0 ||= $MainWin->optionGet('tkPalette','*');
		$c = $c0  if ($c0);
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c);
		}
		$c = '';
	}
	if ($c)
	{
		$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c);
		unless ($fg)
		{
			if ($palette)
			{
				$fg = 'green';
			}
			else
			{
				$fg = $MainWin->cget('-foreground');
			}
		}
		unless ($bg)
		{
			if ($palette)
			{
				$bg = 'black';
			}
			else
			{
				$bg = $MainWin->cget('-background');
			}
		}
	}
	else
	{
		if ($v)
		{
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
			$c = $MainWin->optionGet('tkVpalette','*');
#			$c ||= 'bisque3';
			$fg ||= 'black';
#			$bg ||= 'bisque3';
			if ($c)
			{
				$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
						: $MainWin->setPalette($c)
			}
		}
		else
		{
			$fg = 'green'  unless ($fg);
			$bg = 'black'  unless ($bg);
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
#			$c = $MainWin->optionGet('tkPalette','*');
#			$MainWin->setPalette($c)  if ($c);
		}
	}
	$fgisblack = 1  if ($fg =~ /black/io);
	$fg = $oldfg || 'green'  if ($fgsame);
	$bg = $oldbg || 'black'  if ($bgsame);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-background => $bg)  if ($bg);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));

	#NOW FIX THE TEXT CURSOR!!!!

	my ($red, $green, $blue) = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->rgb(
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-background'));
	my @rgb = sort {$b <=> $a} ($red, $green, $blue);
	my $max = $rgb[0]+$rgb[1];  #TOTAL BRIGHTEST 2.
	my $csrFG;
	if ($max > 52500)  #LOOKS GOOD FOR ME.
	{
		$csrFG = "black";      #SPEED LIMIT 70
	}
	else
	{
		$csrFG = "white";      #NIGHT 65
	}
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-insertbackground => $csrFG);

	&setFont($font)  if ($font =~ /\d/o);
}

sub accept_drop
{
	my($c, $seln) = @_;
	my $filename;
	my $own =  $c->SelectionExists('-selection'=>$seln);
	my @targ = $c->SelectionGet('-selection'=>$seln,'TARGETS');
	foreach (@targ)
	{
		if (/FILE_NAME/o)
		{
			$filename = $c->SelectionGet('-selection'=>$seln,'FILE_NAME');
			last;
		}
		if ($^O eq 'MSWin32' && /STRING/o)
		{
			$filename = $c->SelectionGet('-selection'=>$seln,$_);
			last;
		} 
	}
	if ($filename)
	{
		$filename =~ s#\\#/#go;  #FIX Windoze FILENAMES!
		&openFn($filename);
	}
}

sub backupFn
{
	my $tofid = shift;   #FID IS NOW THE FILE YOU'RE BACKING UP *TO* IF PASSED IN!
	my $fmfid = shift;   # || $cmdfile{$activeTab}[$activeWindow];

	$fmfid = $cmdfile{$activeTab}[$activeWindow]  if (defined($fmfid) && $fmfid == 1);
	my $nostatus = $tofid ? 1 : 0;

print "-???- backup file=$ebackupFid=\n"  if ($debug);
#open JWTDBG,">/tmp/e_dbg.txt"; print JWTDBG "-???- backup file=$ebackupFid=\n"; close JWTDBG;
	if (!$tofid && $ebackupFid && open(T, "<$ebackupFid"))
	{
		binmode T;
		$_ = <T>;
#print "-???- CASH=$_=\n";
		chomp;
		($backups, $backupct) = split(/\,/o);
#print "-!!!- values=$backups,$backupct=\n";
		close T;
		++$backupct;
		$backupct = 0  if ($backupct >= $backups);
		$tofid = "$hometmp/e.${backupct}.tmp";
	}
	$tofid ||= 'e.data.tmp';
	$tofid = $hometmp.'/'.$tofid  unless ($tofid =~ m#^(?:\/|\w\:|\\)#o);
#print "--------from=$fmfid= to=$tofid=\n";
	if ($fmfid)
	{
		copy($fmfid, $tofid);   #EMERGENCY PROTECTION!
		eval { `chmod 777 $tofid`; };
	}
	else
	{
		if ($newsupertext || $AnsiColor)
		{
			$_ = $textScrolled[$activeWindow]->getansi('0.0','end');
		}
		else
		{
			$_ = $textScrolled[$activeWindow]->get('0.0','end');
		}
		if (&writedata($tofid, 1, 2))
		{
			&setStatus("..Could not back up file to \"$tofid\"!");
			return $backupct;
		}
	}
#print "-???-1: status=$nostatus= backupcnt=$backupct=\n";
	unless ($nostatus)
	{
		if ($ebackupFid && open(T, ">$ebackupFid"))
		{
			print T "$backups,$backupct\n";
			close T;
			unless ($nostatus)
			{
				&setStatus("..backed up: backup=$backupct.")  if ($backupct =~ /\d/o);
			}
		}
		else
		{
			&setStatus("..Could not save backup information - $?.");
		}
	}
	return $backupct;
}

sub showbkupFn
{
	my $bk = ($backupct =~ /\d/o) ? $backupct : 'data';
	&setStatus("..Last backup file was: \"$hometmp/e.${bk}.tmp\".");
}

sub doMyCopy
{
	&doCopy;
	my $clipboard;
	eval
	{
		$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
	};
	unless (length $clipboard) {   #ADDED 20080426: NOTHING SELECTED, TRY "YELLOW" TEXT:
		eval
		{
			$textScrolled[$activeWindow]->tagAdd('sel', 
					$textScrolled[$activeWindow]->index('foundme.first'), 
					$textScrolled[$activeWindow]->index('foundme.last'));  #ADDED 20080425
			&doCopy;
			$whichTextWidget->tagRemove('sel','0.0','end');
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		};
	}
	$clipboard =~ s/[\r\n].*$//so;
	&setStatus("..copied selected text ("
			.substr($clipboard,0,20)."...) to clipboard.")
		if ($clipboard);		
}

sub doGetFnKey
{
	return  if ($v);
	my $fnkey = $_[scalar(@_)-1];
	my $selected;
	eval
	{
		$selected = $MainWin->SelectionGet(-selection => 'PRIMARY');
	};
	if (defined $selected && length($selected) && $selected ne $fnkeyText[$fnkey])
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => ("F$fnkey: \"".substr($selected,0,20).'"'));
		}
		else
		{
			$fnMenubtn->entryconfigure("F$fnkey: <undef>", -label => ("F$fnkey: \"".substr($selected,0,20).'"'));
		}
		$fnkeyText[$fnkey] = $selected;
		$textScrolled[$activeWindow]->tagDelete('sel');
	}
	else
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => "F$fnkey: <undef>");
		}
		$fnkeyText[$fnkey] = undef;
	}
}

sub doFnKey    #GIVE THE ABILITY TO HAVE UP TO 5 FUNCTION KEYS SAVED WITH STUFF TO PASTE.
{
	return  if ($v);
	my $fnkey = $_[scalar(@_)-1];

	eval { $whichTextWidget->delete('sel.first','sel.last'); };
	$textScrolled[$activeWindow]->tagDelete('foundme');	
	if ($fnkey == 3 && !$SuperText)    #THIS HACK TO FIX BIND ISSUE WITH <F3> (SUPERTEXT GETS THIS RIGHT, THOUGH)!
	{
		my $clipboard = '';
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		};
		my $l = length($clipboard);
		if ($l > 0)
		{
			eval { $whichTextWidget->delete("insert - $l char",'insert'); };
		}
	}

	$textScrolled[$activeWindow]->insert('insert', $fnkeyText[$fnkey]);
	my $l = length($fnkeyText[$fnkey]);
	$textScrolled[$activeWindow]->tagAdd('foundme', "insert - $l char", 'insert');
	$textScrolled[$activeWindow]->tagConfigure('foundme',
			-relief => 'raised',
			-borderwidth => 1,
			-background  => 'yellow',
			-foreground  => 'black');
	Tk->break;
}

sub doClearFnKeys
{
	for (my $fnkey=1;$fnkey<=12;$fnkey++)
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => "F$fnkey: <undef>");
		}
		$fnkeyText[$fnkey] = undef;
	}
	@fnkeyText = (0);
}

sub doSaveFnKeys
{
	my $anythingDefined = 0;
	for (my $fnkey=1;$fnkey<=12;$fnkey++)
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$anythingDefined = 1;
			last;
		}
	}
	if ($anythingDefined)
	{
		if (open (OUT, ">${homedir}.myefns"))
		{
			$_ = '';
			for (my $fnkey=1;$fnkey<=12;$fnkey++)
			{
				$_ .= $fnkeyText[$fnkey] . "\x02\n";
			}
			chop; chop;
			print OUT $_;
			close OUT;
		}
	}
	else
	{
		unlink "${homedir}.myefns";
	}
}

sub doLoadFnKeys
{
	@fnkeyText = (0);
	if (open (IN, "${homedir}.myefns"))
	{
		my $fnkey = 1;
		my $s = '';
		while (<IN>)
		{
			$s .= $_;
		}
		close IN;
		my @v = split(/\x02\n/o, $s);
		while (@v)
		{
			$_ = shift(@v);
			if (length($_))
			{
				if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
				{
					$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => ("F$fnkey: \"".substr($_,0,20).'"'));
				}
				else
				{
					$fnMenubtn->entryconfigure("F$fnkey: <undef>", -label => ("F$fnkey: \"".substr($_,0,20).'"'));
				}
				$fnkeyText[$fnkey] = $_;
			}
			else
			{
				if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
				{
					$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => "F$fnkey: <undef>");
				}
				$fnkeyText[$fnkey] = undef;
			}
			++$fnkey;
		}
	}
}

sub updateSearchHistory
{
	my $found = 0;
	@srchTextChoices = $srchText->choices();
	for (my $i=0;$i<=$#srchTextChoices;$i++)
	{
		if ($srchTextChoices[$i] eq $srchTextVar)
		{
			$found = 1;
			last;
		}
	}
	unless ($found)
	{
		shift(@srchTextChoices);
		unshift(@srchTextChoices, $srchTextVar);
		unshift(@srchTextChoices, '');
	}
	$srchOptChoices{$srchTextVar} = $srchopts;
	$replTextChoices{$srchTextVar} = $replText->get;
}

sub splitScreen
{
	my $openDialog = shift || 0;

	my (@geometry) = ($MainWin->width, $MainWin->height);

	$textScrolled[0]->packPropagate('1');
	$textScrolled[1]->packPropagate('1');
	my $wasHeight = $text1Frame->height;
	if ($scrnCnts{$activeTab} == 2)
	{
		my ($usrres) = $No;

		my $inActiveWindow = $activeWindow;
		$activeWindow = ($inActiveWindow ? 0 : 1);   #ACTIVE WINDOW IS ONE WE'RE FIXING TO CLOSE!
		my $saveActiveWindowFromFocus = $activeWindow;
		$saveDialog->configure(
				-text => "Save any changes to $cmdfile{$activeTab}[$activeWindow]?");
		$usrres = $saveDialog->Show()  unless($v);
		$activeWindow = $saveActiveWindowFromFocus;
		my ($cancel) = 0;
		$cancel = &saveFn  if ($usrres eq $Yes);
		if (!$cancel && $usrres ne $Cancel)
		{
			#$textScrolled[1]->Subwidget($textsubwidget)->configure(
			#		-height => $height);
			$textAdjuster->packForget();
			$textScrolled[$activeWindow]->packForget();
#			$fileMenubtn->entryconfigure('Single screen',  -label => 'Split screen');
			$fileMenubtn->entryconfigure('Single screen',  -state => 'disabled');
			$fileMenubtn->entryconfigure('Split screen',  -state => 'normal');
			$textScrolled[$inActiveWindow]->Subwidget($textsubwidget)->configure(
					-height => $height);
			$textScrolled[$inActiveWindow]->configure(
					-height => $height);
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
					-height => $height);
			$textScrolled[$activeWindow]->configure(
					-height => $height);
			$textScrolled[$inActiveWindow]->packConfigure(-fill => 'both', -expand => 1);
			$textScrolled[$inActiveWindow]->focus();
			$scrnCnts{$activeTab} = 1;
			my $lastMenuItem = $markMenubtn->menu->index('end');
			$markMenubtn->menu->delete($markMenuTop+1,'end')  if ($lastMenuItem > $markMenuTop);
			foreach my $i (keys %{$markHash{$activeTab}[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
			{
				delete $markHash{$activeTab}[$activeWindow]->{$i};
				delete $markWidget{$activeTab}[$activeWindow]{$i};
				$markMenuIndex{$activeTab}[$activeWindow][$markMenuHash{$activeTab}[$activeWindow]{$i}->{index}] = 0;
				delete $markMenuHash{$activeTab}[$activeWindow]{$i};
			}
			for (my $i=0;$i<=$#{$markMenuIndex{$activeTab}[$activeWindow]};$i++)
			{
				if ($markMenuIndex{$activeTab}[$activeWindow][$i] && $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]})
				{
					$markMenubtn->command(
							-label => $markMenuIndex{$activeTab}[$activeWindow][$i],
							-underline => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$i]}->{underline} || '0',
							-command => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$i]}->{command});
				}
			}
			$marklist{$activeTab}[$activeWindow] = ':insert:sel:';
		}
		$activeWindow = $inActiveWindow;
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
	}
	else
	{
		$textScrolled[0]->packForget();
		$textScrolled[1]->packForget();
#		$fileMenubtn->entryconfigure('Split screen',  -label => 'Single screen');
		$fileMenubtn->entryconfigure('Split screen',  -state => 'disabled');
		$fileMenubtn->entryconfigure('Single screen',  -state => 'normal');
		$scrnCnts{$activeTab} = 2;
		my $setHeight =  int($height / 2);
		$textScrolled[0]->configure(
				-height => $setHeight);
		$textScrolled[1]->configure(
				-height => $setHeight);
		$textScrolled[1]->pack(
				-side   => 'bottom',
				-expand => 'yes',
				-fill   => 'both');
		$textScrolled[0]->pack(
				-side   => 'bottom',
				-expand => 'yes',
				-fill   => 'both');
		$textAdjuster->packAfter($textScrolled[1], -side => 'bottom');

		$textScrolled[1]->focus();
		$text1Frame->packPropagate('1');
		$activeWindow = 1;
#print "-??????- AW=$activeWindow=\n";
		if ($openDialog)
		{
			&openFn()  unless (length($textScrolled[1]->get('1.0','3.0')) > 1);
		}
	}
}

sub resetFileType
{
	my $filetype = shift;
	
	unless ($fileTypes{$filetype})
	{
#		$perlMenubtn = undef;
		if ($filetype == 1)
		{
			#eval {require 'e_c.pl';};
			require 'e_c.pl';
		}
		elsif ($filetype == 2)
		{
			#eval {require 'e_htm.pl';};
			require 'e_htm.pl';
		}
		else
		{
			#eval {require 'e_pl.pl';};
			require 'e_pl.pl';
		}
		$fileTypes{$filetype} = 1;
	}
}

sub doColorEditor
{
	unless ($textColorer)
	{
		$textColorer = $MainWin->ColorEditor(-title => 'Select your favorite colors!');
		$textColorer->configure(
				-widgets=> [$text1Text, $textScrolled[$activeWindow]->Descendants])  unless ($bummer);
	}
	$textColorer->Show();
}

sub showFileName
{
	my $fid = $cmdfile{$activeTab}[$activeWindow];
	unless ($fid =~ m#^(?:\/|\w\:)#o)
	{
		$_ = &cwd();
		$_ .= '/'  unless (m#\/$#o || $fid =~ m#^(?:\/|\w\:)#o);
		$fid = $_ . $fid;
		$fid =~ s#\/[^\/]+\/\.\.\/#\/#o;
		$fid =~ s#\/\.\/#\/#o;
	}
	&setStatus($cmdfile{$activeTab}[$activeWindow] ? $fid : '--untitled--');
	if ($cmdfile{$activeTab}[$activeWindow])   #NOW PUT THE FULL FILENAME INTO THE CLIPBOARD!
	{
		eval {
			$MainWin->SelectionOwn(-selection => 'CLIPBOARD');
			$MainWin->clipboardClear;
			$MainWin->clipboardAppend('--',$fid);
			if (defined($ENV{CLIPBOARD_FID}))
			{
				if (open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
				{
					binmode CLIPBRD;
					print CLIPBRD $fid;
					close CLIPBRD;
				}
			};
		};
	}
}

sub setStatus
{
	$statusLabel->configure( -text => $_[0]);
	$saveStatus{$activeTab}[$activeWindow] = $_[0];
}

sub toggleNB
{
	if ($nb)
	{
		$nb = 0;
		$fileMenubtn->entryconfigure('Turn on backup',  -label => 'Turn OFF backup');
	}
	else
	{
		$nb = 1;
		$fileMenubtn->entryconfigure('Turn OFF backup',  -label => 'Turn on backup');
	}
}

sub kateExt
{
	my $fid = shift;
	
#	my %extHash = (
#		'.pl' => ($havePerlCool ? 'PerlCool' : 'Perl'),
#		'.htm' => 'Kate::HTML',
#		'.html' => 'Kate::HTML',
#		'.js' => 'Kate::JavaScript',
#		'.java' => 'Kate::Java',
#		'.c' => 'Kate::C',
#		'.h' => 'Kate::C',
#		'.cpp' => 'Kate:Cplusplus',
#		'.sh' => 'Kate::Bash',
#		'.css' => 'Kate::CSS',
#		'.for' => 'Kate::Fortran',
#		'.f77' => 'Kate::Fortran',
#		'.ps' => 'Kate::PostScript',
#		'.py' => 'Kate::Python',
#		'.sql' => 'Kate::SQL',
#		'.tdf' => 'Kate::SQL',
#		'.xml' => 'Kate::XML',
#		'.jsp' => 'Kate::JSP',
#		'.def' => 'Kate::Modulaminus2',
#		'.mod' => 'Kate::Modulaminus2'
#	);

     my $haveKateExt = 0;
	foreach my $e (keys %{$kateExtensions}) {
		$kateExtensions->{$e} = 'HTML'  if ($kateExtensions->{$e} eq 'Kate::HTML');
		$kateExtensions->{$e} = 'Bash'  if ($kateExtensions->{$e} eq 'Kate::Bash');
#print "-???- kateExt($e)=$kateExtensions->{$e}= fid=$fid=\n";
		return $kateExtensions->{$e}  if ($fid =~ /$e/i);
		$haveKateExt = 1;
	}
	return (defined($defaulthighlight) && $defaulthighlight) ? $defaulthighlight : 'None';
}

sub beginUndoBlock
{
	my $whichTextWidget = shift;

	if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
	{
		eval { $whichTextWidget->_beginUndoBlock };
	}
	else
	{
		eval { $whichTextWidget->addGlobStart };
	}
}

sub endUndoBlock
{
	my $whichTextWidget = shift;

	if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
	{
		eval { $whichTextWidget->_endUndoBlock };
	}
	else
	{
		eval { $whichTextWidget->addGlobEnd };
	}
}

sub editfile
{
	for (my $i=0;$i<=1;$i++)
	{
		if ($cmdfile{$activeTab}[$i])
		{
			&saveTags($cmdfile{$activeTab}[$i]);
			&saveMarks($cmdfile{$activeTab}[$i], $i);
		}
	}
	my $curposn = $textScrolled[$activeWindow]->index('insert');
	my $cmd = $0;
	$cmd =~ s/\bv([\w\.]*)/e$1/;
	my $cmdArgs = $cmdfile{$activeTab}[$activeWindow];
	system "$cmd -nb -l=$curposn $cmdArgs &";
}

sub switchPgm
{
	my $switchin2E = shift;

	for (my $i=0;$i<=1;$i++)
	{
		if ($cmdfile{$activeTab}[$i])
		{
			&saveTags($cmdfile{$activeTab}[$i]);
			&saveMarks($cmdfile{$activeTab}[$i], $i);
		}
	}
	my $nb = '-nb';
	unless ($switchin2E)
	{
		return  if (&exitFn($No, 'NOEXIT') eq $Cancel);
		$nb = '';
	}

	my $curposn = $textScrolled[$activeWindow]->index('insert');
	my $cmd = $0;
print "-???- BEF: cmd=$cmd= sw2e=$switchin2E=\n"  if ($debug);
	if ($switchin2E)
	{
		$cmd =~ s/\bv([\w\.]*)/e$1/;
	}
	else
	{
		$cmd =~ s/\be([\w\.]*)/v$1/;
	}
print "-???- AFT: cmd=$cmd=\n"  if ($debug);
	if ($nobrowsetabs)
	{
		if ($scrnCnts{$activeTab} == 2)
		{
			exec "$cmd $nb -l=$curposn -focus=$activeWindow $cmdfile{$activeTab}[0] $cmdfile{$activeTab}[1]";
		}
		else
		{
			exec "$cmd $nb -l=$curposn $cmdfile{$activeTab}[$activeWindow]";
		}
	}
	else
	{
		my @tablist = $tabbedFrame->pages();
#print "-???- TAB LIST=".join('|',@tablist)."= ACTIVE=$activeTab=\n";
		my $cmdArgs = '';
		my $t = shift(@tablist);
		$t0 = 'Tab1';
		$cmdArgs = "-focustab=$t0 -focus=$activeWindows{$t0} "
				.$cmdArgs  if ($t0 eq $activeTab);
		my $i = 1;
		foreach my $t (@tablist)
		{
			$t0 = 'Tab'.$i;
			next  unless ($cmdfile{$t}[0] =~ /\S/o || $cmdfile{$t}[1] =~ /\S/o);
			$cmdArgs .= " -tab$i=".$cmdfile{$t}[0];
			$cmdArgs .= ":".$cmdfile{$t}[1]  if ($scrnCnts{$t});
print "-???2- t0=$t0= t=$t= AT=$activeTab= cmdargs=$cmdArgs=\n"  if ($debug);
			$cmdArgs = "-focustab=Tab".($i+1)." -focus=$activeWindows{$t} "
					.$cmdArgs  if ($t eq $activeTab);
			++$i;
		}
		$cmdArgs .= ' '.$cmdfile{$t0}[0];
		$cmdArgs .= ' '.$cmdfile{$t0}[1]  if ($scrnCnts{$t0});
#		$cmdArgs = "-focustab=$t0 -focus=$activeWindows{$t0} "
#					.$cmdArgs  if ($t0 eq $activeTab);
#print "-???1- t=$t0= cmdargs=$cmdArgs=\n";
print "-!!!- WILL EXEC($cmd -nb -l=$curposn $cmdArgs)!\n"  if ($debug);
		exec "$cmd -nb -l=$curposn $cmdArgs";
	}
}

sub fixAfterStep   #TRYIN TO MAKE OUR STUPID W/M RESTORE FOCUS?!?!?! :(
{
	$MainWin->state('normal');
	$MainWin->focus();
print "-2--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]= (FIX AFTERSTEP)\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus();
	$MainWin->raise();
	$MainWin->focus(-force);
}

__END__
