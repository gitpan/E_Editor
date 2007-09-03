#!/perl/bin/perl -s 

#NOTE: Windows compile:  perl2exe -gui -perloptions="-p2x_xbm -s" e.pl
#NOTE: POD compile:  pp -g -M Tk::ROText -M Tk::Text::SuperText -M Tk::TextHighlight -M Tk::TextHighlight::Perl -o ee.exe e.pl
#NOTE: POD compile:  pp -g -M Tk::ROTextANSIColor -M Tk::Text::ROSuperText -M Tk::ROTextHighlight -M Tk::TextHighlight::Perl -M Tk::XMLViewer -o vv.exe v.pl

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
	if ($0 =~ /exe$/i)
	{
		while (@INC)
		{
			$_ = shift(@INC);
			push (@myNewINC, $_)  if (/(?:cache|CODE)/);
		}
		@INC = @myNewINC;
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

#$v = 1  if ($0 =~ /v(\.pl)?$/i);   #CHGD. TO NEXT 20040915.
$v = 1  if ($0 =~ /v\w*\./i);

#FETCH ANY USER-SPECIFIC OPTIONS FROM e.ini:

$homedir ||= $ENV{HOME} || &cwd();
$homedir .= '/'  unless ($homedir =~ m#\/$#);
my $curdir = &cwd();
$curdir .= '/'  unless ($curdir =~ m#\/$#);
$_ = ($0 =~ m#\/([^\/]+)$#) ? $1 : $0;;
s/(\w+)\.\w+$/$1\.ini/g;

while ($curdir) {
	last  if (-r "${curdir}$_");
	chop $curdir;
	last  unless ($curdir);
	$curdir =~ s#\/[^\/]+$#\/#o;
}

unless ($curdir)
{
	$_ = $0;
	s/(\w+)\.\w+$/$1\.ini/g;
}

if (open PROFILE, "${curdir}$_")
{
	while (<PROFILE>)
	{
		chomp;
		s/[\r\n\s]+$//;
		s/^\s+//;
		next  if (/^\#/);
		($opt, $val) = split(/\=/, $_, 2);
		${$opt} = $val  if ($opt);
	}
	close PROFILE;
}
eval 'use Tk::ROText; 1';
if ($v)
{
#print "-V viewer=$viewer=\n";
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
	}
}
else
{
	if ($editor eq 'TextHighlight')
	{
		eval 'use Tk::TextHighlight; $haveTextHighlight = 1; 1';
#		eval 'use Tk::CoolText::$cooltext; 1'  if ($cooltext);
		eval 'use Tk::TextHighlight::PerlCool; $havePerlCool = 1; 1';
	}
	elsif ($editor)
	{
		eval "use Tk::$editor; 1";
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
#print "-???- codetext=$codetext=\n";
if ($haveTextHighlight)
{
	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	%{$extraOptsHash{texthighlight}} = (-syntax => ($codetext||$havePerlCool), -autoindent => 1, -rulesdir => ($codetextdir||$ENV{HOME}),
			-indentchar => ($notabs ? $tspaces : "\t")
	);
	%{$extraOptsHash{ROTextHighlight}} = (-syntax => ($codetext||$havePerlCool), -autoindent => 1, -rulesdir => ($codetextdir||$ENV{HOME}),
			-indentchar => ($notabs ? $tspaces : "\t")
	);
}

#eval 'require "BindMouseWheel.pl"; $WheelMouse = 1; 1';
eval
{
	require "BindMouseWheel.pl"; $WheelMouse = 1;
};
#print "-eval returned =$@=  wm=$WheelMouse= package=".__PACKAGE__."=\n";

use Tk::JFileDialog;

#-----------------------

$vsn = '4.40';

$editmode = 'Edit';
if ($v)
{
#	$SuperText = 0;
	$editmode = 'View';
#	$haveTextHighlight = 0;
}

$bummer = 1  if ($^O =~ /Win/);
$pgmhome = $0;
$pgmhome =~ s#[^/]*$##;  #SET NAME TO SQL.PL FOR ORAPERL!
$pgmhome ||= './';
$pgmhome .= '/'  unless ($pgmhome =~ m#/$#);
$pgmhome = 'c:/perl/bin/'  if ($bummer && $pgmhome =~ /^\.[\/\\]$/);

$hometmp = (-w "${homedir}tmp") ? "${homedir}tmp" : '/tmp';
#$hometmp =~ s#\/#\\#g  if ($bummer);  #CHGD. TO NEXT. 20050401.
if ($bummer)
{
	$hometmp =~ s#\/#\\#g;
	$hometmp = '\\' . $hometmp  unless ($hometmp =~ m#^(?:\\|\w\:)#);
	unless (-w $hometmp)
	{
		$hometmp = 'C:' . $hometmp  unless ($hometmp =~ m#^\w\:#);
		$hometmp =~ s/^\w\:/C\:/  unless (-w $hometmp);
	}
}
$startpath = '.';
@fnkeyText = (0);
$srchopts = '-nocase';
@srchTextChoices = ('');
%replTextChoices = ('' => '');
%srchOptChoices = ('' => $srchopts);
$srchTextVar = '';
$markSelected = '';

##if ($bummer)
eval {$host = `uname -n` || 'Windows';};
chomp($host);
$host ||= 'Windows';
$titleHeader = "${host}: Perl/Tk Editor v$vsn";
if (($f && open(T, $f)) || open(T, ".myefonts") 
		|| open (T, "${homedir}.myefonts") || open (T, "${pgmhome}myefonts"))
{
	my $i = 0;
	while (<T>)
	{
		chomp;
		next  if (/^\#/);
		($fontnames[$i], $fixedfonts[$i]) = split(/\:/);
		$fixedfonts[$i] =~ s/\#.*$//;
		$i++;
	}
	close T;
}
else
{
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
$marklist[0] = ':insert:sel:';
$marklist[1] = ':insert:sel:';

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
	if ($font =~ /^\d+$/)
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
$c = $palette  if ($palette);
my $fgisblack;
$fgisblack = 1  if ($fg =~ /black/i); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!

$bgOrg = $bg;
$fgOrg = $fg;
if ($c)
{
	unless ($c eq 'none')
	{
		if ($c =~ /default/i)  #ADDED 20040827 TO ALL TEXT COLOR TO CHG W/O CHANGING PALETTE.
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
				if ($v && /tkVpalette\s*\=\s*\"([^\"]+)\"/)
				{
					$c = $1;
					last;
				}
				if (/tkPalette\s*\=\s*\"([^\"]+)\"/)
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
		$c ||= 'bisque3';
		$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
				: $MainWin->setPalette($c)
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
	$viewer ||= 'XMLViewer'  if ($haveXML && $ARGV[0] =~ /\.(?:xml|xsd|xsl)$/i);
	$textwidget = $viewer;
	unless ($textwidget)
	{
		$textwidget = 'ROText';
		$textwidget = 'ROTextANSIColor'  if ($AnsiColor && !$noac);
		$textwidget = 'ROSuperText'  if ($SuperText);
	}
	$SuperText = 0  if ($viewer && $viewer !~ /supertext/i);
	$AnsiColor = 0  unless ($textwidget =~ /^(?:ROSuperText|ROTextANSIColor)$/);
}
else
{
	$SuperText = 0  if ($editor && $editor !~ /supertext/i);
	$AnsiColor = 0  unless ($textwidget =~ /^(?:SuperText|TextANSIColor)$/);
}
my ($mytextrelief) = 'sunken';
$mytextrelief = 'groove'  if ($v);
$bottomFrame = $MainWin->Frame;
$lognbtnFrame = $bottomFrame->Frame;
$text1Frame = $bottomFrame->Frame;
#%nextwrap = ('none' => 'Wrap word', 'word' => 'Wrap char', 'char' => 'Wrap none');
$wrap = 'none'  unless (defined($wrap));
$tagcnt = 0;

my $newsupertext;
if ($SuperText && !$noac && !$v)
{
	$textsubwidget = $SuperText ? 'supertext' : 'textundo';
#print "-???e- textwidget=$textwidget=\n";
	$textScrolled[0] = $text1Frame->Scrolled($textwidget,
			-scrollbars => 'se', -ansicolor => 1);
	$textAdjuster = $text1Frame->Adjuster();
	$textScrolled[1] = $text1Frame->Scrolled($textwidget,
			-scrollbars => 'se', -ansicolor => 1);
	$newsupertext = 1;
}
unless ($newsupertext)
{
#print "-???v- textwidget=$textwidget=\n";
	$textScrolled[0] = $text1Frame->Scrolled($textwidget,
			-scrollbars => 'se');
	$textAdjuster = $text1Frame->Adjuster();
	$textScrolled[1] = $text1Frame->Scrolled($textwidget,
			-scrollbars => 'se');
}
Tk::Autoscroll::Init($textScrolled[0])  if ($autoScroll);
&BindMouseWheel($textScrolled[0])  if ($WheelMouse);
&BindMouseWheel($textScrolled[1])  if ($WheelMouse);

if ($v)
{
	$textsubwidget = ($AnsiColor && !$noac) ? 'rotextansicolor' : 'rotext';
	$textsubwidget = 'rosupertext'  if $SuperText;
	$textsubwidget = "\L$viewer\E"  if ($viewer);
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
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/i));
	$textScrolled[1]->Subwidget($textsubwidget)->configure(
			-background => $bg)  if ($bg);
	$textScrolled[1]->Subwidget($textsubwidget)->configure(
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/i));
}
else
{
	$textsubwidget = $SuperText ? 'supertext' : 'textundo';
	$textsubwidget = "\L$editor\E"  if ($editor);
#print "-subwidget=$textsubwidget=\n";
	#$text1Text = $textScrolled[0]->Subwidget('textundo')->configure(
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
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/i));
	$textScrolled[1]->Subwidget($textsubwidget)->configure(
			-background => $bg)  if ($bg);
	$textScrolled[1]->Subwidget($textsubwidget)->configure(
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/i));
	#THIS KLUDGE NECESSARY BECAUSE DUAL-SPEED SETPALETTE BROKEN ON WINDOZE!
}
if ($haveTextHighlight && ($editor =~ /texthighlight/io || $viewer =~ /texthighlight/io))
{
	my $sections;
	($sections, $kateExtensions) = $textScrolled[0]->Subwidget($textsubwidget)->fetchKateInfo;
	$textScrolled[0]->Subwidget($textsubwidget)->addKate2ViewMenu($sections);
	$textScrolled[1]->Subwidget($textsubwidget)->addKate2ViewMenu($sections);
}

$whichTextWidget = $textScrolled[0]->Subwidget($textsubwidget);

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
		-underline =>0,
		-command => \&newFn);
$fileMenubtn->command(
		-label => 'Open',
		-underline =>0,
		-command => \&openFn);
$fileMenubtn->command(
		-label => 'Save',
		-underline =>0,
		-command => \&saveFn);
$fileMenubtn->command(
		-label => ($v ? 'Save Marks/Tags' : 'Save w/Marks'),
		-underline => ($v ? 5 : 7),
#		-command => [\&saveFn, 3]);
		-command => sub { 
			if ($v)
			{
				&saveTags($cmdfile[$activeWindow]);
				&saveMarks($cmdfile[$activeWindow]);
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
		-command => [\&splitScreen]);
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
$scrnCnt = 1;
$fileMenubtn->separator;
if ($v)
{
	$fileMenubtn->command(
			-label => 'Edit w/E',
			-command => sub {
				for (my $i=0;$i<=1;$i++)
				{
					if ($cmdfile[$i])
					{
						&saveTags($cmdfile[$i]);
						&saveMarks($cmdfile[$i]);
					}
				}
				my $cmd = $0;
				$cmd =~ s/\bv([\w\.]*)/e$1/;
				exec "$cmd -nb $cmdfile[0] $cmdfile[1]";
			});
}
else
{
	$fileMenubtn->command(
			-label => 'View w/V',
			-command => sub {
				&exitFn($No, 'NOEXIT');
				my $cmd = $0;
				$cmd =~ s/\be([\w\.]*)/v$1/;
				exec "$cmd -nb $cmdfile[0] $cmdfile[1]";
			});
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
$editMenubtn->command(-label => 'Undo',
		-underline =>0,
		-accelerator => 'Alt-u',
		-command => sub {$textScrolled[$activeWindow]->undo;});

$editMenubtn->command(-label => 'Left-indent', -underline => 0, -command => [\&doIndent,0]);
$editMenubtn->command(-label => 'Right-indent', -underline => 0, -command => [\&doIndent,1]);
#$editMenubtn->command(-label => $nextwrap{$wrap}, -underline => 0, -command => [\&setwrap]);
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
		-label => 'New Mark',
		-underline => 0,
		-command => \&addMark);

$markMenuHash{'Clear Marks'}->{index} = 0;
$markMenuHash{'Clear Marks'}->{underline} = 0;
$markMenuHash{'Clear Marks'}->{command} = \&clearMarks;
$markMenuIndex[0] = 'Clear Marks';
$markMenuHash{'New Mark'}->{index} = 1;
$markMenuHash{'New Mark'}->{underline} = 0;
$markMenuHash{'New Mark'}->{command} = \&addMark;
$markMenuIndex[1] = 'New Mark';
$markNextIndex = 2;

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
		($themename, $themecode) = split(/\:/);
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
#	$tagMenubtn = $w_menu->Menubutton(
#			-text => 'Tags',
#			-state => 'disabled');
#	$tagMenubtn->pack(-side=>'left');
	$fnMenubtn = $w_menu->Menubutton(
			-text => 'Fn',
			-state => 'disabled');
	$fnMenubtn->pack(-side=>'left');

}
else
{
	$fnMenubtn = $w_menu->Menubutton(
			-text => 'Fn'
	);
	$fnMenubtn->pack(-side=>'left');
	for (my $i=1;$i<=5;$i++)
	{
		if (defined($fnkeyText[$i]) && length($fnkeyText[$i]) > 0)
		{
			$fnMenubtn->command(-label => ("F$i: \"".substr($fnkeyText[$i],0,10).'"'), -underline => 1, -command => [\&doGetFnKey, $i]);
		}
		else
		{
			$fnMenubtn->command(-label => "F$i: <undef>", -underline => 1, -command => [\&doGetFnKey, $i]);
		}
	}
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
		-pady   => '1m');

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

#$textColorer->configure(
#		-widgets=> [$text1Text, $textScrolled[$activeWindow]->Descendants])  unless ($bummer);

$statusLabel = $MainWin->Label(
		-justify=> 'left',
		-relief	=> 'groove',
		-borderwidth => 2,
		-text		=> 'Status Label');
$statusLabel->pack(-side => 'bottom',
		-fill	=> 'x',
		-padx	=> '2m',
		-pady	=> '1m');

$textScrolled[0]->bind('<FocusIn>' => sub {
		&textfocusin; $activeWindow = 0;
		$whichTextWidget = $textScrolled[0]->Subwidget($textsubwidget);
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[$activeWindow]\"");
		$opsys = $opsysList[$activeWindow];
});
$textScrolled[0]->bind('<Alt-l>' => [\&shocoords,0]);
$textScrolled[0]->bind('<F1>' => [\&doFnKey,1]);
$textScrolled[0]->bind('<F2>' => [\&doFnKey,2]);
$textScrolled[0]->bind('<F3>' => [\&doFnKey,3]);
$textScrolled[0]->bind('<F4>' => [\&doFnKey,4]);
$textScrolled[0]->bind('<F5>' => [\&doFnKey,5]);
$textScrolled[1]->bind('<FocusIn>' => sub {
		&textfocusin; $activeWindow = 1;
		$whichTextWidget = $textScrolled[1]->Subwidget($textsubwidget);
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[$activeWindow]\"");
		$opsys = $opsysList[$activeWindow];
});
$textScrolled[1]->bind('<Alt-l>' => [\&shocoords,0]);
$textScrolled[1]->bind('<F1>' => [\&doFnKey,1]);
$textScrolled[1]->bind('<F2>' => [\&doFnKey,2]);
$textScrolled[1]->bind('<F3>' => [\&doFnKey,3]);
$textScrolled[1]->bind('<F4>' => [\&doFnKey,4]);
$textScrolled[1]->bind('<F5>' => [\&doFnKey,5]);
if ($SuperText == 1 || $editor =~ /texthighlight/io)
{
	$textScrolled[0]->bind('<Control-p>' => sub
	{
			$textScrolled[0]->Subwidget($textsubwidget)->markSet('_prev','insert');
			$textScrolled[0]->Subwidget($textsubwidget)->jumpToMatchingChar();
			&shocoords(0);
	});
}
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
$opsysList[0] = $opsys;
$opsysList[1] = $opsys;

$asdosButton = $lognbtnFrame->JBrowseEntry(
		-label => '',
		-state => 'readonly',
		-textvariable => \$opsys,
		-choices => [qw(DOS Unix Mac)],
		-listrelief => 'flat',
		-relief => 'sunken',
		-takefocus => 0,
		-browse => 1,
		-browsecmd => sub { $opsysList[$activeWindow] = $opsys },
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

$textScrolled[0]->focus;

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

#&setTheme($themeHash{$theme})  if ($theme && defined $themeHash{$theme});

if ($ARGV[0])
{
	$ARGV[0] =~ s/^file://;  #HANDLE KFM DRAG&DROP!
	$ARGV[0] =~ s#\\#/#g;    #FIX Windoze FILENAMES!

	if (&fetchdata($ARGV[0]))
	{
		$cmdfile[0] = $ARGV[0];
		my $cmdfid = '';
		$cmdfid = &cwd()  unless ($cmdfile[0] =~ m#^(?:\/|\w\:)# );
		if ($cmdfid)
		{
			$cmdfid .= '/'  unless ($cmdfid =~ m#\/$#);
		}
		$cmdfid .= $cmdfile[0];
		$cmdfid =~ s#^\.\/#&cwd."\/"#e;
		$cmdfid =~ s!^(\~\w*)!
			my $one = $1 || $ENV{USER};
			my $t = `ls -d $one`;
			chomp($t);
			$t;
		!e;
		$startpath = $cmdfid;
		$startpath =~ s#[^\/]+$##;
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
		if ($ARGV[1])   #IF 2ND FILE SPECIFIED, SPLIT SCREEN & OPEN IN BOTTOM.
		{
			$cmdfile[1] = $ARGV[1];
			&splitScreen();
			$textScrolled[1]->focus();
			$activeWindow = 1;
			$whichTextWidget = $textScrolled[1]->Subwidget($textsubwidget);
			if (&fetchdata($ARGV[1]))
			{
				my $cmdfid = '';
				my $cmdfid = &cwd()  unless ($cmdfile[1] =~ m#^(?:\/|\w\:)# );
				if ($cmdfid)
				{
					$cmdfid .= '/'  unless ($cmdfid =~ m#\/$#);
				}
				$cmdfid .= $cmdfile[1];
				$cmdfid =~ s#^\.\/#&cwd."\/"#e;
				$cmdfid =~ s!^(\~\w*)!
					my $one = $1 || $ENV{USER};
					my $t = `ls -d $one`;
					chomp($t);
					$t;
				!e;
				$startpath = $cmdfid;
				$startpath =~ s#[^\/]+$##;
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
		$cmdfile[0] = $ARGV[0]  if ($ARGV[0]);
	}
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[0]\"");
	$dontaskagain = 1  unless ($ask);
}
elsif (!$n && !$new)
{
	my $clipboard;
	my $useSelection = ($bummer) ? 'CLIPBOARD' : 'PRIMARY';
	eval { $clipboard = $MainWin->SelectionGet(-selection => $useSelection); };
#2	if ($haveTextHighlight && ($editor =~ /texthighlight/i || $viewer =~ /texthighlight/i) && $bg eq 'black')
#2	{
#2		$MainWin->update;
#2		eval { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->setRule('DEFAULT','-foreground','white'); };
#2		eval { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->setRule('Label','-foreground','white'); };
#2	}
#print STDERR "-at 1\n";
	if ($clipboard)
	{
		$textScrolled[$activeWindow]->insert('end',$clipboard);
		$MainWin->title("$titleHeader, ${editmode}ing:  \"--SELECTED TEXT--\"");
		$_ = "..Successfully opened Selected Text.";
		$statusLabel->configure(-text => $_);
		$textScrolled[$activeWindow]->markSet('insert','0.0');
	}
	else
	{
		$MainWin->title("${host}: Perl/Tk Editor, bv$vsn, ${editmode}ing:  \"--NEW DOCUMENT--\"");
	}
	$cmdfile[0] = '';
}
#2elsif ($haveTextHighlight && ($editor =~ /texthighlight/i || $viewer =~ /texthighlight/i) && $bg eq 'black')
#2{
#2		$MainWin->update;
#2		eval { $textScrolled[0]->Subwidget($textsubwidget)->setRule('DEFAULT','-foreground','white');
#2		$textScrolled[0]->Subwidget($textsubwidget)->setRule('Label','-foreground','white');
#2		$textScrolled[1]->Subwidget($textsubwidget)->setRule('DEFAULT','-foreground','white');
#2		$textScrolled[1]->Subwidget($textsubwidget)->setRule('Label','-foreground','white'); };
#2	}
#print STDERR "-at 2\n";

$filetype = 0;

if ($cmdfile[0] =~ /\.c$/i || $cmdfile[0] =~ /\.h$/i || $cmdfile[0] =~ /\.cpp$/i)
{
	#eval {require 'e_c.pl';};  #EVAL DOESN'T WORK HERE IN COMPILED VSN.
	require 'e_c.pl';
	$filetype = 1;
}
elsif ($cmdfile[0] =~ /\..*ht[a-z]+/i)
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
$text1Text->focus;
#########$textScrolled[$activeWindow]->bind('<ButtonRelease>' => [\&shocoords,1])  if (defined($v));   #REMOVED FOR SUPERTEXT!
#$text1Text->bind('<<MouseSelectAutoScanStop>>' => [\&shocoords,1]);  #ADDED FOR SUPERTEXT!
#unless (defined($v))
{
	$textScrolled[0]->Subwidget($textsubwidget)->bind('<ButtonRelease-1>' => [\&shocoords,1]);
	$textScrolled[1]->Subwidget($textsubwidget)->bind('<ButtonRelease-1>' => [\&shocoords,1]);
}
$textScrolled[0]->bind('<Alt-a>' => sub { &doSearch(0) });
$textScrolled[1]->bind('<Alt-a>' => sub { &doSearch(0) });
$textScrolled[$activeWindow]->markSet('insert','0.0');

&gotoMark($textScrolled[$activeWindow],$l)  if ($l);
&doSearch(2)  if ($s);

$MainWin->bind('<Alt-b>' => [\&gotoMark, '_Bookmark']);

#SPECIAL CODE IF VIEWING ONLY!

if ($v)
{
	$editMenubtn->entryconfigure('cuT', -state => 'disabled');
	$editMenubtn->entryconfigure('Paste (Clipboard)', -state => 'disabled');
	$editMenubtn->entryconfigure('Paste (Primary)', -state => 'disabled');
	$editMenubtn->entryconfigure('Undo', -state => 'disabled');
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
#		$_ = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->index('insert'); 
#		if ($_ eq $textScrolled[$activeWindow]->Subwidget($textsubwidget)->index('insert lineend'))
#		{
#			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->markSet('insert',"insert + 1 line linestart");
#			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->see('insert');
#		}
});
$MainWin->bind('<Alt-Right>' => sub { 
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->xview('scroll', +1, 'units');
#		$_ = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->index('insert'); 
#		if ($_ eq $textScrolled[$activeWindow]->Subwidget($textsubwidget)->index('insert linestart'))
#		{
#			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->markSet('insert',"insert - 1 char");
#			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->see('insert');
#		}
});
$MainWin->bind('<Alt-Up>' => sub { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->yview('scroll', -1, 'units') });
$MainWin->bind('<Alt-Down>' => sub { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->yview('scroll', +1, 'units') });

#&setTheme($themeHash{$theme})  if ($theme && defined $themeHash{$theme});

#MainLoop;
while (Tk::MainWindow->Count)
{
	#if (Exists($xpopup2))
	if ($childpid)
	{
		if ($childpid)
		{
			@children = `ps ef|grep "$childpid"|grep -v "grep"`;
			$childstillrunning = 0;
			while (@children)
			{
				$_ = shift(@children);
				if (/^\D*(\d+)/)
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
	#$MainWin->update;
	DoOneEvent(ALL_EVENTS);
}

sub newFn
{
	my ($usrres);
	$usrres = $No;
	unless ($v)
	{
		if (length($textScrolled[$activeWindow]->get('1.0','1.1')))
		{
			$saveDialog->configure(
					-text => "Save any changes to $cmdfile[$activeWindow]?");
			$usrres = $saveDialog->Show();		
			$cmdfile[$activeWindow] ||= "$hometmp/e.out.tmp";
		}
	}
	$_ = '';
	$usrres = $Cancel x &writedata($cmdfile[$activeWindow])  if ($usrres eq $Yes);
	return  if ($usrres eq $Cancel);
	$cmdfile[$activeWindow] = '';
	$textScrolled[$activeWindow]->delete('0.0','end');
	&clearMarks();
	$opsysList[$activeWindow] = $bummer ? 'DOS' : 'Unix';
	$MainWin->title("$titleHeader, ${editmode}ing:  New File");
}

sub openFn		#File.Open (Open a different command file)
{
	my ($openfid) = shift;
	my ($usrres);
	$usrres = $No;
	unless ($v)
	{
		if (length($textScrolled[$activeWindow]->get('1.0','1.1')))
		{
			$saveDialog->configure(
					-text => "Save any changes to $cmdfile[$activeWindow]?");
			$usrres = $saveDialog->Show();		
			$cmdfile[$activeWindow] ||= "$hometmp/e.out.tmp";
		}
	}
	$_ = '';
	$usrres = $Cancel x &writedata($cmdfile[$activeWindow])  if ($usrres eq $Yes);
	return  if ($usrres eq $Cancel);
	my ($savefile) = $cmdfile[$activeWindow];
	if ($openfid || !&getcmdfile("Select file to $editmode"))
	{
		$cmdfile[$activeWindow] = $openfid  if ($openfid);
		if (&fetchdata($cmdfile[$activeWindow]))
		{
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[$activeWindow]\"")
		}
		else
		{
			$cmdfile[$activeWindow] = $savefile;
		}
	}
	else
	{
		$cmdfile[$activeWindow] = $savefile  unless (defined($cmdfile[$activeWindow]));
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
			-Create => 1);

	my $fid = $fileDialog->Show;
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	return  unless ($fid =~ /\S/);
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
	$_ .= "\n"  if ($_ && $lastpos =~ /\.0$/);
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
	#$cancel = &getcmdfile(1)  unless ($cmdfile[$activeWindow] gt ' ');
	$cancel = &getcmdfile("Save file as")  unless ($cmdfile[$activeWindow] =~ /\S/);
	return ($cancel)  if ($cancel);   #getcmdfile() returns 1 if no filename entered!
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[$activeWindow]\"");
	$_ = '';
	my $usrres = $Yes;
	if (-e $cmdfile[$activeWindow])
	{
		my (@fidinfo) = stat($cmdfile[$activeWindow]);
		my $msg;
#		$msg = "file \"$cmdfile[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
#				if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
		$msg = "file \"$cmdfile[$activeWindow]\"\nexists! overwrite?"
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
		return (&writedata($cmdfile[$activeWindow], 0, $saveopt));
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
		$_ .= "\n"  if ($_ && $lastpos =~ /\.0$/);
		$printedselected = 1;
	}
	&writedata("$hometmp/e.out.tmp", $printedselected, 2);
	my $mytitle = $cmdfile[$activeWindow];
	$mytitle =~ s/\s/_/g;
	$intext .= " -o\"title=$mytitle\" "  if ($cmdfile[$activeWindow] && $intext =~ /post/ && $intext !~ /title/);  #SPECIAL FEATURE FOR MY "POST" SCRIPTS!
	if ($intext =~ /^\s*\|/)
	{
		`cat $hometmp/e.out.tmp $intext &`;
	}
	else
	{
		`$intext $hometmp/e.out.tmp`;
	}
	if ($?)
	{
		$statusLabel->configure(-text=>"..Could not print ($intext) - $?.");
	}
	elsif ($printedselected)
	{
		$statusLabel->configure(-text=>"..printed ($intext) selected text.");
	}
	else
	{
		$statusLabel->configure(-text=>"..printed ($intext) all text.");
	}
}

sub exitFn 	#File.Save (Save changes to command file)
{
	my $saveDefaultYN = shift || $No;

	my ($cancel) = 0;
	#$cancel = &getcmdfile(1)  unless ($cmdfile[$activeWindow] gt ' ');
#	$cancel = &getcmdfile("Save file as")  unless ($cmdfile[$activeWindow] =~ /\S/o);
#	return ($cancel)  if ($cancel);
	$_ = '';
	my ($msg, @wins);
	if ($scrnCnt == 2)
	{
		@wins = (0, 1);
	}
	else
	{
		@wins = ($activeWindow);
	}
	my ($usrres);
	my $saveActive = $activeWindow;
	my $saveActiveWindowFromFocus;
	my $whichWindowIndicator = ($#wins >= 1) ? '(Top window) ' : '';
#print STDERR "-wins=".join('|',@wins)."= scrncnt=$scrnCnt= aw=$activeWindow=\n";
	foreach $activeWindow (@wins)
	{
		$usrres = $saveDefaultYN;
		$_ = '';
#print STDERR "----- sd=$saveDefaultYN= ur=$usrres= dontask=$dontaskagain= fid=$cmdfile[$activeWindow]=\n";
		#DEFAULT=NO OR CMDFILE IS EMPTY OR (ASKAGAIN && CMDFILE EXISTS):
		if ($saveDefaultYN eq $No || $cmdfile[$activeWindow] !~ /\S/o || (!$dontaskagain && -e $cmdfile[$activeWindow]))
		{
#			$usrres = $v ? $No : $Cancel;
			$saveActiveWindowFromFocus = $activeWindow;
			$whichWindowIndicator =~ s/Top/Bottom/o  if ($activeWindow);
#print STDERR "-???- v=$v= fid=$cmdfile[$activeWindow]=\n";
			unless ($v || $cmdfile[$activeWindow] =~ /\S/o)
			{
				$usrres = $No;
				$saveDialog->configure(
						-text => "Save ${whichWindowIndicator}data to a file?");
				$usrres = $saveDialog->Show();
				if ($usrres eq $No)
				{
					&backupFn("e.after$activeWindow.tmp")  unless ($v);
				}
				next  unless ($usrres eq $Yes);
				&getcmdfile("Save ${whichWindowIndicator}data as");
#print STDERR "-???- fid=$cmdfile[$activeWindow]= intext=$intext= cash=$_=\n";
			}
			$msg = '';
			if (-e $cmdfile[$activeWindow])
			{
#print STDERR "-!!!- somehow file ($cmdfile[$activeWindow]) ".((-e $cmdfile[$activeWindow]) ? 'EXISTS' : 'Does not exist').".\n";
				$msg = "${whichWindowIndicator}file \"$cmdfile[$activeWindow]\"\nexists! overwrite?";
				if ($chkacc)
				{
					my (@fidinfo) = stat($cmdfile[$activeWindow]);
					$msg = "${whichWindowIndicator}file \"$cmdfile[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
							if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
				}
			}
			elsif ($usrres eq $No)
			{
				$msg = "Save any ${whichWindowIndicator}changes to $cmdfile[$activeWindow]?";
			}
			if ($msg)
			{
				$saveDialog->configure(
						-text => $msg);
				$usrres = $saveDialog->Show()  unless ($v);
			}
			$activeWindow = $saveActiveWindowFromFocus;
		}
		#return  if (($usrres eq $Yes) && &writedata($cmdfile[$activeWindow]));
		#print "..File \"$cmdfile[$activeWindow]\" saved.\n"  if ($usrres eq $Yes);
		#exit(0);
		$_ = '';
#print "-9- res=$usrres= aw=$activeWindow=\n";
		if ($usrres eq $Yes)
		{
#			$dontaskagain = 1  unless ($ask > 1);
			return  if (&writedata($cmdfile[$activeWindow]));
			print "..File \"$cmdfile[$activeWindow]\" saved.\n";
		}
		elsif ($usrres eq $No)
		{
			&backupFn("e.after$activeWindow.tmp")  unless ($v);
		}
		elsif ($usrres eq $Cancel)
		{
			last;
		}
	}
	$activeWindow = $saveActive;
	if ($usrres ne $Cancel)
	{
		exit (0)  unless (shift);
	}
}

sub saveasFn		#File.save As (Save under new name)
{
	my ($savefile) = $cmdfile[$activeWindow];
	my $saveopt = shift;

	unless (&getcmdfile("Save file as"))
	{
		my ($usrres) = $Yes;
		if (!$dontaskagain && -e $cmdfile[$activeWindow])
		{
			$usrres = $Cancel;
			$saveDialog->configure(
					-text => "file \"$cmdfile[$activeWindow]\"\nexists! overwrite?");
			$usrres = $saveDialog->Show();
		}
		$_ = '';
		if ($usrres eq $Yes)
		{
			&writedata($cmdfile[$activeWindow], 0, $saveopt);
			$dontaskagain = 1  unless ($ask > 1);
		}
	}
#	$cmdfile[$activeWindow] = $savefile;	 #KEEP OLD FILENAME AS DEFAULT SAVE / COMMENT OUT TO MAKE SAVE-AS NAME THE DEFAULT SAVE NAME FOR FUTURE SAVES!
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[$activeWindow]\"");
}

sub getcmdfile          #PROMPT USER FOR NAME OF DESIRED COMMAND FILE.  RETURNS 1 ON FAILURE/CANCEL
{
	my ($opt) = shift;
	$intext = undef;
	local $_;
#print "-???- h=$histFile= p=$pathFile=\n";
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => $opt || 'Select file to edit',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 16,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-Create => 1);
	$intext = $fileDialog->Show;
	#$startpath = $fileDialog->{Configure}{-Path};
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	#$intext = undef  if ($intext le ' ');
	$intext = undef  if ($intext !~ /\S/o);
	#$cmdfile = $intext  if (defined($intext));
	if (defined($intext))
	{
		$cmdfile[$activeWindow] = $intext;
		$dontaskagain = 0  if ($ask);
	}
	return $cmdfile[$activeWindow]  unless ($opt);   #APPEARS NOT 2B USED.
#	return (1)  unless (defined($intext) && $intext gt ' ');
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
		$markMenubtn->menu->delete(0,'end');
		foreach my $i (keys %{$markHash[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
		{
			delete $markHash[$activeWindow]->{$i};
			delete $markWidget{$i};
			$markMenuIndex[$markMenuHash{$i}->{'index'}] = 0;
			delete $markMenuHash{$i};
		}
		for (my $i=0;$i<=$#markMenuIndex;$i++)
		{
			if ($markMenuIndex[$i] && $markMenuHash{$markMenuIndex[$i]})
			{
				$markMenubtn->command(
						-label => $markMenuIndex[$i],
						-underline => $markMenuHash{$markMenuIndex[$i]}->{underline} || '0',
						-command => $markMenuHash{$markMenuIndex[$i]}->{command});
			}
		}
		$marklist[$activeWindow] = ':insert:sel:';
		for ($i=1;$i<=$tagcnt;$i++)
		{
			eval {$whichTextWidget->tagDelete("foundme$i");};
		}
		$tagcnt = 0;
		$_ = <INFID>;
		$opsys = (s/\r\n/\n/g) ? 'DOS' : 'Unix';
		$opsys = 'Mac'  if (s/\r/\n/g);
		$opsysList[$activeWindow] = $opsys;
		my $indata = $_;
		while (<INFID>)
		{
			s/\r\n?/\n/g;
			$indata .= $_;
		}
		close INFID;
		if ($textsubwidget =~ /xmlviewer/i)
		{
			$textScrolled[$activeWindow]->insertXML(-text => $indata);
			unless (defined($alreadyHaveXMLMenu[$activeWindow])
					&& $alreadyHaveXMLMenu[$activeWindow])
			{
				$textScrolled[$activeWindow]->XMLMenu;
				$alreadyHaveXMLMenu[$activeWindow] = 1;
			}
		}
		else
		{
			if ($haveTextHighlight && ($editor =~ /texthighlight/io || $viewer =~ /texthighlight/io))
			{
				if ($codetext)
				{
					my $langModule = ($codetext eq 'Kate') ? &kateExt($fid) : $codetext;
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => $langModule);
				}
				elsif ($fid =~ /\.html?$/io)
				{
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'HTML');
				}
	#			elsif ($fid =~ /\.js$/io)
	#			{
	#				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
	#						-syntax => 'Kate::JavaScript');
	#			}
				elsif ($fid =~ /\.sh$/io)
				{
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'Bash');
				}
				else
				{
					my $langModule = &kateExt($fid) || 'PerlCool';
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => $langModule);
				}
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure('-rules' => undef);
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->highlightPlug;
#3#				if ($bg eq 'black')
#3				#FOR SOME STRANGE REASON, WE STILL NEED NEXT 10 LINES, THOUGH CODETEXT SAIS IT'S DOING THIS?!?
#3				my ($red, $green, $blue) = $MainWin->rgb($textScrolled[$activeWindow]->cget(-background));   #JWT: NEXT 8 ADDED 20070802 TO PREVENT INVISIBLE TEXT!
#3				my @rgb = sort {$b <=> $a} ($red, $green, $blue);
#3				my $max = $rgb[0]+$rgb[1];  #TOTAL BRIGHTEST 2.
#3				if ($max <= 52500)
#3				{
#3					$MainWin->update;
#3					eval { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->setRule('DEFAULT','-foreground','white'); };
#3					eval { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->setRule('Label','-foreground','white'); };
#3					$MainWin->update;
#3				}
#3print STDERR "-at 3\n";
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
		$cmdfile[$activeWindow] = $fid;
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$fid\"");
		$textScrolled[$activeWindow]->markSet('insert','0.0');
		if (($newsupertext || $AnsiColor) && -r "${fid}.etg" && open (INFID, "${fid}.etg"))
		{
			my ($onoff, $tagtype, $tagindx, %tagStartHash);
			while (<INFID>)
			{
				s/s+$//;
				($onoff, $tagtype, $tagindx) = split(/\:/);
				if ($onoff eq '-')
				{
					if ($tagStartHash{$tagtype})
					{
						if ($tagtype =~ /ul$/)
						{
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype, -underline => 1);
						}
						elsif ($tagtype =~ /bd$/)
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
				$mkPosn =~ s/\s+$//;    #FOR SOME REASON, CHOMP NOT WORKIN'?!
				&addMark($mkName, $mkPosn)  if ($mkPosn =~ /^[\d\.]+$/);
			}
			close INFID;
			unlink "${fid}.emk";
		}
		unless ($v)
		{
			#$backupct = &backupFn($fid);
			$backupct = &backupFn($nb ? 'e.before.tmp' : 0);
		}
		$_ = "..Successfully opened file: \"$fid\".";
		unless ($v || $nb)
		{
			$_ .= " backup=$backupct."  if ($backupct =~ /\d/);
		}
		$statusLabel->configure(-text => $_);
		return 1;
	}
	else
	{
		$statusLabel->configure(-text=>"..Could not open file: \"$fid\"!");
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
			-Create => 0);

	$fid = $fileDialog->Show;
	#$startpath = $fileDialog->{Configure}{-Path};
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	return  unless ($fid =~ /\S/);

	if (open(INFID,$fid))
	{
		binmode INFID;
		$textScrolled[$activeWindow]->markSet('selstartmk','insert');
		$textScrolled[$activeWindow]->markGravity('selstartmk','left');
		$textScrolled[$activeWindow]->markSet('selendmk','insert');
		$textScrolled[$activeWindow]->markGravity('selendmk','right');
		while (<INFID>)
		{
			s/\r\n?/\n/g;
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
		$statusLabel->configure(-text=>"..Could not open file: \"$fid\"!");
	}
}

sub writedata
{
	my ($fid) = shift;
	my $opt = shift || 0;
	my $saveopt = shift || 0;
	
#		$msg = "file \"$cmdfile[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
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
		if ($! =~ /Too many open files/)  #MUST "REPLACE" FILES ON WEBFARM?!
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
		$statusLabel->configure(-text=>"e:Could not save $fid ($!)!");
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
	s/\r\n/\n/g;
	if ($opsysList[$activeWindow] eq 'DOS')
	{
		s/\n/\r\n/g;
  	}
	elsif ($opsys eq 'Mac')
	{
		s/\n/\r/g;
	}
	print OUTFID;
	close OUTFID;
	&saveTags($fid)  if ($saveopt != 2);
	&saveMarks($fid)  if ($saveopt == 3 || $savemarks);
	$statusLabel->configure(-text=>"..Edits saved to file: \"$fid\".");
}

sub saveMarks
{
	my $ffid = $_[0] . '.emk';
	my @marks = keys %markMenuHash;
	my ($m, $mk);
	if ($#marks > 1)
	{
		foreach $m (@marks)
		{
			if ($markMenuHash{$m}->{markposn})
			{
				if (open(OUTFID, ">$ffid"))
				{
					foreach $mk (@marks)
					{
						print OUTFID "$mk=".$markMenuHash{$mk}->{markposn}."\n";
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
			if ($xdump[$i+1] =~ /^ANSI/)
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
	unless (defined($clipboard) && $clipboard =~ /\S/)
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		}
		;
	}

	$startattop = 1  if ($newsearch);
	$xpopup->destroy  if (Exists($xpopup));
	$MainWin->focus(-force);
	$whichTextWidget->Subwidget($textsubwidget)->focus;
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
			$xpopup->destroy;
			eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
			$MainWin->focus(-force);
			$whichTextWidget->Subwidget($textsubwidget)->focus;
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
	#$gsrButton->configure(-state => 'disabled')  if ($v);
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
			$srchTextVar = ($cmdfile[$activeWindow] =~ /\.(?:js|.*ht.+)$/i) ? '^(alert)' : '^(print|for)';
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
		#$srchText->delete('0','end'); 
		#$srchText->insert('0','sub ');
		$srchTextVar = ($cmdfile[$activeWindow] =~ /\.(?:js|.*ht.+)$/i) ? 'function ' : 'sub ';
		$srchText->icursor(length($srchTextVar));
	}
	)->pack(-side=>'left', -expand=>1, -pady => 6);

	my $canButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Cancel',
			-underline => 0,
			-command => sub
	{
		$xpopup->destroy;
		eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		$MainWin->focus(-force);
		$whichTextWidget->Subwidget($textsubwidget)->focus;
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
		#$srchText->insert('end',$srchstr)  unless ($newsearch || $srchstr le ' ');
		$srchTextVar .= $srchstr;
	}
#	else
#	{
#		eval
#		{
#			my ($clipboard);
#			$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
#			$srchText->insert('insert',$clipboard);
#			$activewidget->tagRemove('sel','0.0','end');
#		}
#	}
	$replText->insert('end',$replstr)  unless ($newsearch || $replstr le ' ');
	$srchText->focus;
}

sub doSearch
{
####	my ($whichTextWidget) = shift;
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
		$srchopts = '-nocase'  if ($srchstr =~ s#/i$##);
		$srchwards = 1;
	}
	else
	{
		$srchstr = $srchTextVar  if ($newsearch);
		eval { $replstr = $replText->get }  if ($newsearch);  #PRODUCES ERROR SOMETIMES W/O EVEL?!?!?!
		if (Exists($xpopup))
		{
			$xpopup->destroy;
		}
		$MainWin->focus(-force);
		$whichTextWidget->Subwidget($textsubwidget)->focus;
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
		$statusLabel->configure(-text=>"..Found \"$srchstr\" at position $srchpos");
##		eval {$whichTextWidget->tagRemove('sel','0.0','end')
##				unless ($whichTextWidget->get('sel.first','sel.last') ne 
##				$whichTextWidget->get('foundme.first','foundme.last')); };    #ADDED 20030211.
		$whichTextWidget->tagDelete('foundme');
##		$whichTextWidget->tagAdd('sel', $srchpos, "$srchpos + $lnoffset char");    #ADDED 20030211.
		$whichTextWidget->tagAdd('foundme', $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure('foundme',
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'yellow',
				-foreground     => 'black');
		$srchpos = $whichTextWidget->index("$srchpos + $lnoffset char");
		$whichTextWidget->markSet('_prev','insert');
		$whichTextWidget->markSet('insert',$srchpos);
		$srchpos = $whichTextWidget->index('foundme.first')  unless ($srchwards);
		$whichTextWidget->see($srchpos);
		my ($replstrx) = $replstr;
		if ($replstr =~ /\S/ and !$v)
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
#					$chgstr =~ s/\Q$srchstr\E/$replstrx/eig; #CHGD. TO NEXT 20050331.
					$chgstr =~ s/\Q$srchstr\E/$replstrx/eigs;
				}
				else
				{
#					$chgstr =~ s/\Q$srchstr\E/$replstrx/eg; #CHGD. TO NEXT 20050331.
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
		$statusLabel->configure(-text=>"..Did not find \"$srchstr\".");
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
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	my $indentStr = $notabs ? $tspaces : "\t";

	$textScrolled[$activeWindow]->markSet('selstart','sel.first linestart - 2 char');
	if ($lastpos =~ /\.0$/)
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
		#$clipboard =~ s/\n/\n\t/g;    #CHGD. TO NEXT 6 20031009 - LEAVE HEREDOC ENDTAGS & COMMENTS ALONE!
		my @l = split(/\n/, $clipboard, -1);
		for (my $i=0;$i<=$#l;$i++)
		{
			$l[$i] = $indentStr . $l[$i]  unless ($l[$i] !~ /\S/ || ($l[$i] =~ /^(?:\#.*|\w+(?:\:\s*\;\s*)?)$/ && $l[$i] !~ /^else\s*$/i));
		}
		$clipboard = join("\n", @l);
	}
	else                     #SHIFT ALL LINES LEFT 1 TAB-STOP OR 3 SPACES.
	{
		$clipboard =~ s/\n(\t|$tspaces)/\n/g;
	}
	$textScrolled[$activeWindow]->delete('sel.first linestart - 1 char','selend');
	$textScrolled[$activeWindow]->insert('insert',$clipboard);
	if ($lastpos =~ /\.0$/)
	{
		$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend');
	}
	else
	{
		$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend + 1 char');
	}
}

sub setcase
{
	my ($whichflag) = shift;
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	#my ($textScrolled[$activeWindow]) = &getactive();

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
		#if ($lastpos =~ /\.0$/)
		#{
		#	$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend');
		#}
		#else
		#{
		my ($l) = length($clipboard) - 1;
		$textScrolled[$activeWindow]->tagAdd('sel',"selend - $l char",'selend');
		#}
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
	$errline =~ s/\D//g;
	&gotoMark($textScrolled[$activeWindow], $errline);
	#$textScrolled[$activeWindow]->focus;
	#$textScrolled[$activeWindow]->markSet('insert',$errline);
	#$textScrolled[$activeWindow]->see($gotopos);
	#$statusLabel->configure(-text=>"Cursor now at $gotopos.");
}

sub doSave
{
	my ($mytitle) = "File to save results:";
	my ($create) = 1;
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title=>$mytitle,
		-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 16,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-Create => $create);

	my ($myfile) = $fileDialog->Show(-Horiz=>0);
	#$startpath = $fileDialog->{Configure}{-Path};
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	if ($myfile =~ /\S/ && open(OUTFID, ">$myfile"))
	{
		binmode OUTFID;
		$_ = $text2Scrolled->get('0.0','end');
		chomp;
		s/\r\n/\n/g;
#		$opsysList[$activeWindow] = $opsys;
		if ($opsys eq 'DOS')
		{
			s/\n/\r\n/g;
	  	}
		elsif ($opsys eq 'Mac')
		{
			s/\n/\r/g;
		}
		print OUTFID;
		close OUTFID;
		$statusLabel->configure(-text=>"..Results saved to file: \"$myfile\".");
		return (0);
	}
	else
	{
		$statusLabel->configure(-text=>"e:COULD NOT SAVE TO \"$myfile\"!");
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
	$markMenubtn->menu->delete(0,'end');
	foreach my $i (keys %{$markHash[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
	{
		delete $markHash[$activeWindow]->{$i};
		delete $markWidget{$i};
		$markMenuIndex[$markMenuHash{$i}->{index}] = 0;
		delete $markMenuHash{$i};
	}
	for (my $i=0;$i<=$#markMenuIndex;$i++)
	{
		if ($markMenuIndex[$i] && $markMenuHash{$markMenuIndex[$i]})
		{
			$markMenubtn->command(
					-label => $markMenuIndex[$i],
					-underline => $markMenuHash{$markMenuIndex[$i]}->{underline} || '0',
					-command => $markMenuHash{$markMenuIndex[$i]}->{command});
		}
	}
	$marklist[$activeWindow] = ':insert:sel:';
}

sub addMark
{
	$intext = shift;
	$mkPosn = shift || 'insert';
	&gettext("Mark Name:",20,'t',2)  unless ($intext);
	$intext = '_Bookmark'  unless ($intext =~ /^[_a-zA-Z0-9]/);
	unless ($intext eq  '*cancel*')
	{
		#unless ($intext !~ /\S/ || $markMenuHash{"$intext"})
		unless ($intext !~ /\S/ || $marklist[$activeWindow] =~ /\:$intext\:/)
		{
			($intext,$ul) = split(/,/,$intext);
			$ul = 0  unless ($ul =~ /^\d+$/);
			$ul = 4  if (!$ul && !$filetype && $intext =~ /^sub /);
			#EVAL SO THAT "$intext" IS SET STATICALLY!
			$markWidget{$intext} = $textScrolled[$activeWindow];
			#########eval { $markMenubtn->menu->delete($intext); };
			$evalstr = "
					\$markMenuHash{\"$intext\"}->{index} = \$markNextIndex;
					\$markMenuIndex[\$markNextIndex] = \"$intext\";
					\$markNextIndex++;
					\$markMenuHash{\"$intext\"}->{underline} = \$ul || '0';
					\$markMenuHash{\"$intext\"}->{command} = sub
					{
						\$markWidget{\"$intext\"}->markSet('_prev','insert');
						\$markWidget{\"$intext\"}->markSet('insert',\"$intext\");
						my (\$gotopos) = \$markWidget{\"$intext\"}->index('insert');

						\$markWidget{\"$intext\"}->see(\$gotopos);
						\$statusLabel->configure(-text=>\"Cursor now at \$gotopos.\");
						\$markWidget{\"$intext\"}->focus;
					};
					\$markMenubtn->command(
						-label => '$intext',
						-underline => \$ul,
						-command => \$markMenuHash{\"$intext\"}->{command}
					);
			";
			eval $evalstr  unless ($markMenuHash{$intext});
			$marklist[$activeWindow] .= ':' . $intext . ':';
		}
		$textScrolled[$activeWindow]->markSet("$intext",$mkPosn);
		delete $markHash[($activeWindow ? 0 : 1)]->{$intext};
		$marklist[($activeWindow ? 0 : 1)] =~ s/\Q\:$intext\E\://;
		$markHash[$activeWindow]->{$intext} = $intext;
		my ($markpos) = $textScrolled[$activeWindow]->index($mkPosn);
		$markMenuHash{$intext}->{markposn} = $markpos;
		$statusLabel->configure(-text=>"Mark \"$intext\" set to $markpos.");
	}
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
	}
	#unless (defined($clipboard))
	unless (length($clipboard) > 0)  #NEXT TRY "FOUND" TEXT (HANDY FOR MARKS)!
	{
		eval
		{
			$clipboard = $textScrolled[$activeWindow]->get('foundme.first','foundme.last');
		}
	}
	#unless (defined($clipboard))
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
			######eval {$activewidget->tagRemove('sel','0.0','end');};
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
		my @markChoices = ('_prev',split(/\:+/, substr($marklist[$activeWindow],13)));
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
	$getText->focus;
	$textPopup->waitWindow;  #WAIT HERE FOR USER RESPONSE!!!
}

sub select2Mark
{
	my $start = $textScrolled[$activeWindow]->index('insert');
	my $end = $textScrolled[$activeWindow]->index($markSelected);
	($end > $start) ? $textScrolled[$activeWindow]->tagAdd('sel', 'insert', $markSelected)
			: $textScrolled[$activeWindow]->tagAdd('sel', $markSelected, 'insert');
#	my $gotopos = ($end > $start) ? $textScrolled[$activeWindow]->index('insert')
#			: $textScrolled[$activeWindow]->index('_prev');
#	$textScrolled[$activeWindow]->see($gotopos);
	$MainWin->focus(-force);
	eval { $textPopup->destroy; };
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$textScrolled[$activeWindow]->markSet('_prev', $start);
	$textScrolled[$activeWindow]->markSet('insert', $end);
	$textScrolled[$activeWindow]->see('insert');
	$statusLabel->configure(-text => "Cursor now at $end.");
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
	$xPopup->destroy;
	$MainWin->focus(-force);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
}

sub gotoMark
{
	my ($self,$intext) = @_;

	$intext .= '.0'  if ($intext =~ /^\d+$/);
	eval 
	{
		if ($markWidget{$intext})
		{
			$markWidget{$intext}->focus;
			$markWidget{$intext}->markSet('_xprev','_prev')  if ($intext eq '_prev');
			$markWidget{$intext}->markSet('_prev','insert');
			$intext = '_xprev'  if ($intext eq '_prev');
			$markWidget{$intext}->markSet('insert',$intext);
			my ($gotopos) = $markWidget{$intext}->index('insert');

			$markWidget{$intext}->see($gotopos);
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
		$statusLabel->configure(-text=>"Cursor now at $gotopos.");
	}
}

sub doGoto
{
	&gettext("Go To (line#.col#):",20,'t',1);
	unless ($intext eq  '*cancel*')
	{
		$intext = '0'  unless ($intext =~ /\S/);
		$intext .= '0'   if ($intext =~ /^\d\.$/);
		if ($intext =~ /^\s*[\+\-]/)
		{
			$intext =~ s/\..*$//;
			eval
			{
				$textScrolled[$activeWindow]->markSet('_prev','insert');
				$textScrolled[$activeWindow]->markSet('insert',"insert $intext lines");
			}
			;
		}
		else
		{
			$intext .= '.0'  if ($intext =~ /^\d+$/);
			eval
			{
				$textScrolled[$activeWindow]->markSet('_xprev','_prev')  if ($intext eq '_prev');
				$textScrolled[$activeWindow]->markSet('_prev','insert');
				$intext = '_xprev'  if ($intext eq '_prev');
				$textScrolled[$activeWindow]->markSet('insert',$intext);
				#$textScrolled[$activeWindow]->markSet('_prev','insert')  unless ($intext eq '_prev');
				#$textScrolled[$activeWindow]->markSet('insert',$intext);
			}
			;
		}
		my ($gotopos) = $textScrolled[$activeWindow]->index('insert');
		$textScrolled[$activeWindow]->see('insert');
		$statusLabel->configure(-text=>"Cursor now at $gotopos.");
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
	$xpopup->destroy  if (Exists($xpopup));
	$MainWin->focus(-force);
	$whichTextWidget->focus;
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
	#$whichTextWidget->markGravity('selstartmk','left');
	$whichTextWidget->markSet('selendmk',$selend);
	#$whichTextWidget->markGravity('selendmk','right');
	#$whichTextWidget->delete($selstart,$selend);

	my ($replstrx) = $replstr;
	$replstrx = ''  if ($replstr eq '``');  #TREAT '' AS EMPTY STR!
	$srchpos = $selstart;
	while (1)
	{
		$srchpos = $whichTextWidget->search(-forwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, 'end');
		last  if not $srchpos;
		$selend = $whichTextWidget->index('selendmk');
		last  if ($srchpos > $selend);
		$whichTextWidget->markSet('insert',$srchpos);
		#$whichTextWidget->tag('add', $tag, $current, "$current + $length char");
		#$current = $w->index("$current + $length char");
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
	$statusLabel->configure(-text=> "..$tagcnt matches of \"$srchstr\" found/changed!");
	$whichTextWidget->tagAdd('sel', 'selstartmk', 'selendmk');

}

sub shocoords
{
	my ($calledbymouse) = shift;
#	$text1Text->SUPER::mouseSelectAutoScanStop;    #ADDED FOR SUPERTEXT!
	$whichTextWidget->mouseSelectAutoScanStop  if ($SuperText && $calledbymouse && !$v);
	my ($gotopos) = $textScrolled[$activeWindow]->index('insert');
	$textScrolled[$activeWindow]->see($gotopos);
	$statusLabel->configure(-text=> $gotopos);
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
	$statusLabel->configure(-text => 'Length = '.length($clipboard));
}

sub showSum
{
	$clipboard = '';
	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	$clipboard = $textScrolled[$activeWindow]->get('0.0','end')  unless ($clipboard);
	my @l = split(/\n/, $clipboard, -1);
	my $columncnt = 0;
	my @sums = ();
	my $columnsnotequal = 0;
	for (my $i=0;$i<=$#l;$i++)
	{
		@numbers = ();
		$j = 0;
		while ($l[$i] =~ s/([\d\+\-\.]+)//)
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
	$statusLabel->configure(-text => 
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
		my @xdump = $textScrolled[$activeWindow]->dump(-tag, $selstart,$selend);
		my (@ansitags) = ();
		for ($i=0;$i<=$#xdump;$i+=3)
		{
			if ($xdump[$i] eq 'tagon')
			{
				if ($xdump[$i+1] =~ /^ANSI/)
				{
					push (@ansitags, $xdump[$i+1]);
				}
			}
		}
		$textScrolled[$activeWindow]->tagDelete(@ansitags);
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
	$fgsame = 1  if ($fg =~ s/same//i);
	$bgsame = 1  if ($bg =~ s/same//i);
	my $fgisblack;
	$fgisblack = 1  if ($fg =~ /black/i); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!
	$c = ''  if ($c =~ /same/i);
	if ($c =~ /default/i)
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
	else
	{
		if ($v)
		{
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
			$c = $MainWin->optionGet('tkVpalette','*');
			$c ||= 'bisque3';
			$fg ||= 'black';
			$bg ||= 'bisque3';
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c)
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
	$fgisblack = 1  if ($fg =~ /black/i);
	$fg = $oldfg || 'green'  if ($fgsame);
	$bg = $oldbg || 'black'  if ($bgsame);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-background => $bg)  if ($bg);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/i));

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

#2	#THIS KLUDGE NECESSARY BECAUSE DUAL-SPEED SETPALETTE BROKEN ON WINDOZE!
#2	if ($bg eq 'black')
#2	{
#2		$MainWin->update;
#2		eval { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->setRule('DEFAULT','-foreground','white');
#2		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->setRule('Label','-foreground','white'); };
#2	}
#print STDERR "-at 4\n";
	&setFont($font)  if ($font =~ /\d/);
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
		$filename =~ s#\\#/#g;  #FIX Windoze FILENAMES!
		&openFn($filename);
	}
}

sub backupFn
{
	my $tofid = shift;   #FID IS NOW THE FILE YOU'RE BACKING UP *TO* IF PASSED IN!
	my $fmfid = shift;   # || $cmdfile[$activeWindow];

	$fmfid = $cmdfile[$activeWindow]  if (defined($fmfid) && $fmfid == 1);
	my $nostatus = $tofid ? 1 : 0;

	if (!$tofid && open(T, "<${homedir}.ebackups"))
	{
		$_ = <T>;
		chomp;
		($backups, $backupct) = split(/\,/);
		close T;
		++$backupct;
		$backupct = 0  if ($backupct >= $backups);
		$tofid = "$hometmp/e.${backupct}.tmp";
	}
	$tofid ||= 'e.data.tmp';
	$tofid = $hometmp.'/'.$tofid  unless ($tofid =~ m#^\/#o);
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
			$statusLabel->configure(-text=>"..Could not back up file to \"$tofid\"!");
			return $backupct;
		}
	}
	unless ($nostatus)
	{
		if (open(T, ">${homedir}.ebackups"))
		{
			print T "$backups,$backupct\n";
			close T;
			unless ($nostatus)
			{
				$statusLabel->configure(-text=>"..backed up: backup=$backupct.")  if ($backupct =~ /\d/);
			}
		}
		else
		{
			$statusLabel->configure(-text=>"..Could not save backup information - $?.");
		}
	}
	return $backupct;
}

sub showbkupFn
{
	my $bk = ($backupct =~ /\d/) ? $backupct : 'data';
	$statusLabel->configure(-text=>"..Last backup file was: \"$hometmp/e.${bk}.tmp\".");
}

sub doMyCopy
{
	&doCopy;
	my $clipboard;
	eval
	{
		$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
	}
	;
	$clipboard =~ s/[\r\n].*$//s;
	$statusLabel->configure(-text=>"..copied selected text ("
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
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,10).'"'), -label => ("F$fnkey: \"".substr($selected,0,10).'"'));
		}
		else
		{
			$fnMenubtn->entryconfigure("F$fnkey: <undef>", -label => ("F$fnkey: \"".substr($selected,0,10).'"'));
		}
		$fnkeyText[$fnkey] = $selected;
		$textScrolled[$activeWindow]->tagDelete('sel');
	}
	else
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,10).'"'), -label => "F$fnkey: <undef>");
		}
		else
		{
			$fnMenubtn->entryconfigure("F$fnkey: <undef>", -label => "F$fnkey: <undef>");
		}
		$fnkeyText[$fnkey] = undef;
	}
	if (defined($selected) && length($selected) > 0)
	{
	}
	else
	{
	}
}

sub doFnKey    #GIVE THE ABILITY TO HAVE UP TO 5 FUNCTION KEYS SAVED WITH STUFF TO PASTE.
{
	return  if ($v);
	my $fnkey = $_[scalar(@_)-1];
	$textScrolled[$activeWindow]->markSet('selstartmk','insert');
	$textScrolled[$activeWindow]->markGravity('selstartmk','left');
	$textScrolled[$activeWindow]->markSet('selendmk','insert');
	$textScrolled[$activeWindow]->markGravity('selendmk','right');
	$textScrolled[$activeWindow]->insert('insert', $fnkeyText[$fnkey]);
	$textScrolled[$activeWindow]->tagDelete('foundme');
	$textScrolled[$activeWindow]->tagAdd('foundme', 'selstartmk', 'selendmk');
	$textScrolled[$activeWindow]->tagConfigure('foundme',
			-relief => 'raised',
			-borderwidth => 1,
			-background  => 'yellow',
			-foreground  => 'black');
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
	my (@geometry) = ($MainWin->width, $MainWin->height);

	$textScrolled[0]->packPropagate('1');
	$textScrolled[1]->packPropagate('1');
	my $wasHeight = $text1Frame->height;
	if ($scrnCnt == 2)
	{
		my ($usrres) = $No;

		my $inActiveWindow = $activeWindow;
		$activeWindow = ($inActiveWindow ? 0 : 1);   #ACTIVE WINDOW IS ONE WE'RE FIXING TO CLOSE!
		my $saveActiveWindowFromFocus = $activeWindow;
		$saveDialog->configure(
				-text => "Save any changes to $cmdfile[$activeWindow]?");
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
			$fileMenubtn->entryconfigure('Single screen',  -label => 'Split screen');
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
			$scrnCnt = 1;
			$markMenubtn->menu->delete(0,'end');
			foreach my $i (keys %{$markHash[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
			{
				delete $markHash[$activeWindow]->{$i};
				delete $markWidget{$i};
				$markMenuIndex[$markMenuHash{$i}->{index}] = 0;
				delete $markMenuHash{$i};
			}
			for (my $i=0;$i<=$#markMenuIndex;$i++)
			{
				if ($markMenuIndex[$i] && $markMenuHash{$markMenuIndex[$i]})
				{
					$markMenubtn->command(
							-label => $markMenuIndex[$i],
							-underline => $markMenuHash{$markMenuIndex[$i]}->{underline} || '0',
							-command => $markMenuHash{$markMenuIndex[$i]}->{command});
				}
			}
			$marklist[$activeWindow] = ':insert:sel:';
		}
		$activeWindow = $inActiveWindow;
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile[$activeWindow]\"");
	}
	else
	{
		$textScrolled[0]->packForget();
		$textScrolled[1]->packForget();
		$fileMenubtn->entryconfigure('Split screen',  -label => 'Single screen');
		$scrnCnt = 2;
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
#print "-set up colorer\n";
		$textColorer->configure(
				-widgets=> [$text1Text, $textScrolled[$activeWindow]->Descendants])  unless ($bummer);
	}
	$textColorer->Show();
}

sub showFileName
{
	my $fid = $cmdfile[$activeWindow];
	unless ($fid =~ m#^(?:\/|\w\:)#)
	{
		$_ = &cwd();
		$_ .= '/'  unless (m#\/$# || $fid =~ m#^(?:\/|\w\:)#);
		$fid = $_ . $fid;
		$fid =~ s#\/[^\/]+\/\.\.\/#\/#o;
		$fid =~ s#\/\.\/#\/#o;
	}
	$statusLabel->configure(-text=> ($cmdfile[$activeWindow] ? $fid : '--untitled--'));
	if ($cmdfile[$activeWindow])   #NOW PUT THE FULL FILENAME INTO THE CLIPBOARD!
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

	foreach my $e (keys %{$kateExtensions}) {
		$kateExtensions->{$e} = 'PerlCool'  if ($kateExtensions->{$e} eq 'Kate::Perl');
		$kateExtensions->{$e} = 'HTML'  if ($kateExtensions->{$e} eq 'Kate::HTML');
		$kateExtensions->{$e} = 'Bash'  if ($kateExtensions->{$e} eq 'Kate::Bash');
		return $kateExtensions->{$e}  if ($fid =~ /$e/i);
	}
	return 'Kate::Perl';
}

__END__

