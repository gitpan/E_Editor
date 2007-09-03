my ($mycmd);
my $setState = $v ? 'disabled' : 'normal';

$perlMenubtn = $w_menu->Menubutton(
	-text => 'HTML',
	-underline => 0);
$perlMenubtn->command(
	-label => 'View',
	-underline =>0,
	-command => [\&perlFn,2]);
$perlMenubtn->command(
	-label => '<Parameter>',
	-underline =>0,
	-state => $setState,
	-command => [\&perlFn,1]);
$perlMenubtn->command(
	-label => 'Reformat',
	-underline =>0,
	-state => $setState,
	-command => [\&perlFn2,8]);

eval {$textScrolled[$activeWindow]->index('sel.first')};

$thismenu = $perlMenubtn;

foreach $i (qw(A B BR BODY CHECKBOX CENTER FONT FORM H1 H2 H3 H4 HEAD HR HTML I IEXCL LI MU NBSP OPTION P QUOTE RADIO SELECT TABLE TD TH TR TEXTAREA UL !EVAL !IF !INCLUDE !LOOP !PERL !SELECTLIST))
{
	if ($i eq 'TABLE')
	{
		$perlMenubtn->cascade(	-label => 'More...', -underline =>0);
		my ($cm) = $perlMenubtn->cget(-menu);
		my ($cc) = $cm->Menu;
		$perlMenubtn->entryconfigure('More...', -menu => $cc);
		$thismenu = $cc;
	}
	$myeval = '		$thismenu->command(	-label => \''.$i.'\', -underline =>0, -state => $setState, -command => [\&perlFn,0,$i]); ';
	eval $myeval;
}

$perlMenubtn->pack(-side=>'left');


sub perlFn
{
	my ($runit) = shift;
	my ($mytag) = shift;

	if ($runit == 1)  #USER'S OWN TAG.
	{
		#######&doCopy();
		&gettext("HTML Tag Name:",20,'t',0,1);
		return  if ($intext eq  '*cancel*');
		my $tagname = $intext;
		$tagname =~ s/^\s*(\w+).*/$1/;
		eval {$textScrolled[$activeWindow]->insert('sel.first',"<!:$intext:>");};
		$@ ? $textScrolled[$activeWindow]->insert('insert',"<!:$intext>") : 
				$textScrolled[$activeWindow]->insert('sel.last',"<!:/$tagname>");
		return;
	}
	elsif ($runit == 2)   #FIRE UP NETSCAPE!
	{
		$_ = '';
		my $browser;   #ADDED 20021007 TO ALLOW USER TO SELECT BROWSER.
		unless (&writedata("$hometmp/e.src.htm"))
		{
			if (open(T, "<$ENV{HOME}/.myebrowser"))
			{
				$browser = <T>;
				chomp ($browser);
			}
			$browser ||= $bummer ? 'start' : 'netscape';
			system "$browser $hometmp/e.src.htm &";
		}
		return;
	}
	else
	{
		#######&doCopy();
		eval {$textScrolled[$activeWindow]->index('sel.first')};
		$intext = '';
		if ($mytag =~ '(A|BODY|CHECKBOX|FONT|FORM|HR|OPTION|RADIO|SELECT|TABLE|TD|TH|TR|TEXTAREA|\!EVAL|\!IF|\!INCLUDE|\!LOOP|\!SELECTLIST)')
		{
			&gettext("$mytag Tag Info:",40,'t',0,1);
			return  if ($intext eq '*cancel*');
			$intext = ' '.$intext  if ($intext =~ /\S/ && $intext !~ /^\_/);
		}
		$pos = 1;
		eval {$pos = $textScrolled[$activeWindow]->index('sel.first');};
		my ($highlighted) = 0;
		$highlighted = 1  unless ($@);
		$pos =~ s/.*\.//;
		#eval {$textScrolled[$activeWindow]->insert('sel.first',"<$mytag$intext>");};
		if ($mytag eq 'NBSP')
		{
			$textScrolled[$activeWindow]->insert('insert','&nbsp;');
			return;
		}
		if ($mytag eq 'MU')
		{
			$textScrolled[$activeWindow]->insert('insert','&micro;');
			return;
		}
		if ($mytag eq 'IEXCL')
		{
			$textScrolled[$activeWindow]->insert('insert','&iexcl;');
			return;
		}
		unless ($highlighted)
		{
			if ($mytag eq 'QUOTE')
			{
				$textScrolled[$activeWindow]->insert('insert','&quot;');
				return;
			}
			$textScrolled[$activeWindow]->insert('insert',"<$mytag$intext>");
			$textScrolled[$activeWindow]->markSet('mymark','insert - 1 char');
			if ($mytag =~ '(A|BODY|FONT|FORM|SELECT|TABLE|TD|TH|TR|TEXTAREA|\!EVAL|\!IF|\!LOOP|\!SELECTLIST)')
			{
				if ($mytag =~ /^!/)
				{
					$textScrolled[$activeWindow]->insert('insert', 
						('<!/'.substr($mytag,1).'>'));
				}
				else
				{
					$textScrolled[$activeWindow]->insert('insert',"</$mytag>");
				}
			}
			$textScrolled[$activeWindow]->markSet('insert','mymark + 1 char');
		}
		else
		{
			my ($startpos) = $textScrolled[$activeWindow]->index('sel.first');
			my ($endpos) = $textScrolled[$activeWindow]->index('sel.last');
			my ($startline) = $startpos;
			$startline =~ s/\..*//;
			my ($endline) = $endpos;
			$endline =~ s/\..*//;
			my ($x) = '';
			my ($x2) = '';
			if (($endline > $startline) && ($startpos =~ /\.0$/) && ($endpos =~ /\.0$/))
			{
				my ($lastline) = $textScrolled[$activeWindow]->get('sel.first','sel.first lineend');
				$x = $1  if ($lastline =~ /^(\s+)/);
				$x =~ s/\t/   /g;
				$x =~ s/   /\t/g;
				my ($tabcnt) = length($x);
				if ($mytag eq 'QUOTE')
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"$x&quot;\n");};
				}
				else
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"$x<$mytag$intext>\n");};
				}
				eval {&doIndent(1);};
				if ($SuperText)
				{
					$x2 = "\n";
				}
				else
				{
					$x = "\n" . $x;
				}
			}
			else
			{
				if ($mytag eq 'QUOTE')
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"&quot;");};
				}
				else
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"<$mytag$intext>");};
				}
			}
			#$textScrolled[$activeWindow]->insert('sel.first',"\n")  unless ($pos);
#POUNDED 20030920			$textScrolled[$activeWindow]->insert('sel.last',"\n")  unless ($pos);
			if ($mytag eq 'QUOTE')
			{
				$textScrolled[$activeWindow]->insert('sel.last',($x.'&quot;'.$x2));
			}
			elsif ($mytag =~ /^!/)
			{
				if ($intext =~ /^_/)   #TAG HAS A LABEL.
				{
					$intext =~ s/^(\S+).*/$1/;
					$textScrolled[$activeWindow]->insert('sel.last', 
						($x.'<!/'.substr($mytag,1).$intext.'>'.$x2));
				}
				else
				{
					$textScrolled[$activeWindow]->insert('sel.last', 
						($x.'<!/'.substr($mytag,1).'>'.$x2));
				}
			}
			else
			{
				$textScrolled[$activeWindow]->insert('sel.last',"$x</$mytag>$x2");
			}
		}
		return;
	}

	$xpopup2->destroy  if (Exists($xpopup2));
	$xpopup2 = $MainWin->Toplevel;
	$xpopup2->title('Perl syntax-check results:');
	$xpopup2->title('Results:')  if ($runit);
	my $w_menu = $xpopup2->Frame(
			-relief => 'raised',
			-borderwidth => 2);
	$w_menu->pack(-fill => 'x');
	
	my $bottomFrame = $xpopup2->Frame;
	my $xpopup2lbl = $bottomFrame->Frame;
	$xpopup2lbl->pack(
		-side	=> 'top',
		-fill   => 'x',
		-padx   => '2m',
		-pady   => '1m');
	my $xpopup2btnFrame = $bottomFrame->Frame;
	$xpopup2btnFrame->pack(
		-side	=> 'bottom',
		-fill   => 'x',
		-padx   => '2m',
		-pady   => '1m');
	
	my $text2Frame = $bottomFrame->Frame;
	$text2Scrolled = $text2Frame->Scrolled('ROText',
		-scrollbars => 'se');
	$text2Text = $text2Scrolled->Subwidget('rotext')->configure(
		-setgrid=> 1,
		-font	=> $fixedfont,
		-tabs	=> ['1.35c','2.7c','4.05c'],
		-insertbackground => 'white',
		-relief => 'sunken',
		-wrap	=> 'none',
		-height => 10,
		-width  => 40);

	my $fileMenubtn = $w_menu->Menubutton(-text => 'File', -underline => 0);
	$fileMenubtn->command(-label => 'Save',    -underline =>0, -command => [\&doSave]);
	$fileMenubtn->separator;
	$fileMenubtn->command(-label => 'Close',   -underline =>0, -command => [$xpopup2 => 'destroy']);
	my $editMenubtn = $w_menu->Menubutton(-text => 'Edit', -underline => 0);
	$editMenubtn->command(
		-label => 'Copy',
		-underline =>0,
		-command => [\&doCopy]);
	$editMenubtn->separator;
	$editMenubtn->command(-label => 'Find',   -underline =>0, -command => [\&newSearch,$text2Scrolled,1]);
	$editMenubtn->command(-label => 'Modify search',   -underline =>0, -command => [\&newSearch,$text2Scrolled,0]);
	$editMenubtn->command(-label => 'Again', -underline =>0, -command => [\&doSearch,$text2Scrolled,0]);

	$fileMenubtn->pack(-side=>'left');
	$editMenubtn->pack(-side=>'left');

	$text2Frame->pack(
		-side	=> 'left',
		-expand	=> 'yes',
		-fill   => 'both',
		-padx   => '2m',
		-pady   => '1m');
	
	$text2Scrolled->pack(
		-side   => 'bottom',
		-expand => 'yes',
		-fill   => 'both');

	#$text2Text->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$text2Scrolled->bind('<FocusIn>' => [\&textfocusin]);
	my $okButton = $xpopup2btnFrame->Button(
		-padx => 11,
		-underline => 0,
		-text => 'Ok',
		-command => sub {$xpopup2->destroy;});
	$okButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
	$bottomFrame->pack(
		-side => 'bottom',
		-fill	=> 'both',
		-expand	=> 'yes');

	$xpopup2->bind('<Escape>'   => [$okButton	=> Invoke]);
	$okButton->focus;
	my ($errline) = undef;
	if (open(TEMPFID,"$hometmp/e.out.tmp"))
	{
		while (<TEMPFID>)
		{
			$errline = $1  if (!defined($errline) && /line (\d+)/);
			$text2Scrolled->insert('end',$_);
		}
		close TEMPFID;
	}
	if (defined($errline))   #IF ERRORS, POSITION CURSOR TO LINE# OF 1ST ERROR!
	{
		#$errline .= '.0';
		my $errButton = $xpopup2btnFrame->Button(
			-padx => 11,
			-underline => 0,
			-text => 'Errors',
			-command => [\&gotoErr, $errline]);
		$errButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
		$errButton->focus;
	}
}

sub perlFn2
{
	my ($which) = shift;

	my ($actualcurpos) = $textScrolled[$activeWindow]->index('insert');
	my ($curpos) = $textScrolled[$activeWindow]->index('insert linestart');
	eval {$curpos = $textScrolled[$activeWindow]->index('sel.first linestart');};
	#my ($startpos) = $curpos;
	my ($startpos) = $textScrolled[$activeWindow]->index('insert');
#print "<BR>startpos was =$startpos=\n";
	my ($linesback) = 0;
	$linesback = 1  if ($actualcurpos =~ /\.0$/);
	$startpos = $curpos;
#print "<BR>startpos  is =$startpos= lb=$linesback=\n";
	my ($highlighted) = undef;
	eval
	{
		$highlighted = $textScrolled[$activeWindow]->get('sel.first','sel.last');
	};

	my ($lastline, $lastchar);
	if ($highlighted)
	{
		$lastline = $textScrolled[$activeWindow]->get("$curpos linestart","$curpos lineend");
	}
	else
	{
		#$lastline = $textScrolled[$activeWindow]->get("$curpos - 1 line linestart","$curpos - 1 line lineend");
		#LAST LINE CHGD TO NEXT 6 20010514.
#print "-cp=$curpos= lb=$linesback=\n";
		#my ($linesback) = 1;
		my ($curline) = $textScrolled[$activeWindow]->get("$curpos linestart","$curpos lineend");
#print "--- curline=$curline=\n";
		do
		{
			$lastline = $textScrolled[$activeWindow]->get("$curpos - $linesback line linestart","$curpos - $linesback line lineend");
#print "-loop- lb=$linesback= ll=$lastline=\n";
			++$linesback;
		} while ($curpos > 0.0 && $lastline !~ /\S/);
#print "-ll=$lastline= lb=$linesback=\n";
		$lastchar = $textScrolled[$activeWindow]->get("insert - 1 char", 'insert');
#print "-???- lc=$lastchar= actual=$actualcurpos=\n";
		if (length($curline) && $curline =~ /\S/)
		{
			if ($lastchar eq '{' || $actualcurpos !~ /\.0/)
			{
#print "------ adding 1!\n";
				$startpos += 1.0;
				$startpos .= '.0';
				$curpos += 1.0;
				$curpos .= '.0';
			}
		}
	}
	my ($x) = '';
	$x = $1  if ($lastline =~ /^(\s+)/);
#print "-lastline indented, x=$x=\n"  if ($lastline =~ /^(\s+)/);
	$x =~ s/\t/   /g;
	$x =~ s/   /\t/g;
	my ($xb) = $x;
	$x = "\t" . $x  if ($lastline =~ /\{\s*$/ || $lastchar eq '{');
#print "-ll ends in curly: x=$x=\n"  if ($lastline =~ /\{\s*$/ || $lastchar eq '{');
	$tabcnt = length($x);
#print "-tabcnt =$tabcnt=\n";
	my ($curskip) = 0;

	&gettext("Starting indent:",3,'t');
	return  if ($intext eq  '*cancel*');
	&reallign();
}

sub reallign
{
	my ($wholething, $selstart, $selend);

	my $curposn = $textScrolled[$activeWindow]->index('insert');
	eval
	{
		$wholething = $textScrolled[$activeWindow]->get('sel.first','sel.last');
		$selstart = $textScrolled[$activeWindow]->index('sel.first');
		$selend = $textScrolled[$activeWindow]->index('sel.last');
	};
	unless (defined($wholething))
	{
		$wholething = $textScrolled[$activeWindow]->get('0.0','end');
		$selstart = '0.0';
		$selend = $textScrolled[$activeWindow]->index('end');
	}
	my (@lines) = split(/\n/, $wholething);

	if (open (TEMPFID,">$hometmp/e.reformat.tmp"))
	{
		print TEMPFID '#LINES: '.$selstart.' - '.$selend."\n";
		print TEMPFID $wholething;
		close TEMPFID;
		`chmod 777 $hometmp/e.reformat.tmp`;
	}
	else
	{
		$statusLabel->configure(-text=>"Could not reformat -- $hometmp/e.reformat.tmp unwritable!");
		return (1);
	}
	my $hereend;
	
	$current_indent = $intext;
	for (my $i=0;$i<=$#lines;$i++)
	{
#print "---next line($i)=$lines[$i]=\n";
		next  if ($lines[$i] =~ /^\#\#*(print|for)/);  #LEAVE OUR DEBUG STUFF ALONE!
		next  if ($lines[$i] =~ /^\#*print/);  #LEAVE OUR DEBUG STUFF ALONE!
		next  if ($lines[$i] =~ /^\s*\#/);     #ADDED 20010514 - LEAVE COMMENTED LINES ALONE!
		next  if ($lines[$i] =~ /^\=\w/);      #ADDED 20010514 - LEAVE POD COMMANDS ALONE!
		if ($hereend)  #LEAVE HERE-STRINGS ALONE!
		{
			$hereend = ''  if ($lines[$i] =~ /^$hereend/);  #LEAVE HERE-STRING ENDTAGS ALONE!
			next;
		}
		$lines[$i] =~ s/^\s+//;
		$lines[$i] =~ s/([\'\"])([^\1]*)?\1/my ($one,$two) = ($1,$2); 
				$two =~ s!\#!\x02!; "$one$two$one"/eg;
		$comment = '';
		$comment = $1  if ($lines[$i] =~ s/^(\#.*)$//);
		$comment = $2  if (!$comment && $lines[$i] =~ s/([^\$])(\#.*)$/$1/);

		$_ = $lines[$i];
		s/\{.*?\}//g;
		$current_indent--  if ($current_indent && /\}\s*$/);
#print "\n-???- ci=$current_indent= lines($i)=$lines[$i]=\n";
		$lines[$i] = ("\t" x $current_indent) . $lines[$i] 
				unless ($lines[$i] =~ s/^\s*(\w+\:)\s*(.*)$/$1.("\t" x $current_indent).$2/e);
		$cont = 0  if ($lines[$i] =~ /^\s*\-/);
		$cont = 0  if ($lines[$i] =~ /^\s*\{/);   #ADDED 20010514
		$lines[$i] = "\t\t" . $lines[$i]  if ($cont);
		$hereend = $1  if ($lines[$i] =~ /\<\<[\'\"]?(\w+)/);  #CHECK `HERE-STRINGS.
		if ($lines[$i] =~ /\}\s*(else.*|elsif.*){\s*$/)   #HANDLE STUFF LIKE "} else {".
		{
#print "($i) case 1\n";
			$current_indent--  if ($current_indent);
			$lines[$i] = ("\t" x $current_indent) . "}\n" 
					. ("\t" x $current_indent) . $1 . "\n"  
					. ("\t" x $current_indent) . "{";
		}
		#if ($lines[$i] =~ /\S\s*\{[^\}]*$/)  #FIX K & R-STYLE BRACES.
#print "---THIS line($i)=$lines[$i]=\n";
		if ($lines[$i] =~ /\S\s*\{\s*$/)  #FIX K & R-STYLE BRACES.
		{
#print "($i) case 2\n";
			$lines[$i] =~ s/\s*\{\s*$//;
			$lines[$i] .= "\n" . ("\t" x $current_indent) . "{";
		}
		if ($lines[$i] =~ /^[^\{\s]+\s*\}/)
		{
#print "($i) case 3\n";
			$lines[$i] =~ s/^[^\{]*\s*\}\s*(.*)$//;
			$current_indent--  if ($current_indent);
			$lines[$i] = ("\t" x $current_indent) . "}\n" 
					. ("\t" x $current_indent) . $1;
		}
		if ($lines[$i] =~ /^[^\{]*\}\s*(\S.*)$/)
		{
#print "($i) case 4\n";
			$current_indent--  if ($current_indent);
			$lines[$i] = ("\t" x $current_indent) . "}\n" 
					. ("\t" x $current_indent) . $1;
		}
		if ($lines[$i] =~ /\{\s*$/ || $lines[$i] =~ /^\s*\{/)
		{
			$current_indent++;
		}
		$cont = 0;
		#$cont = 1  if ($lines[$i] =~ /[\,\'\+\-\=\*\/\"\.\&\|]\s*$/);
		#CHGD TO NEXT LINE 20010514.
		$cont = 1  if ($lines[$i] =~ /[\,\'\+\-\=\*\/\"\.\&\|\(\)]\s*$/);
		$cont = 0  if ($lines[$i] =~ /^\s*\-/);
		$lines[$i] = "\t\t".$lines[$i]  if ($lines[$i] =~ /^\s*\-\S/);
		$lines[$i] .= $comment;
		$lines[$i] =~ s/\x02/\#/g;
		$lines[$i] =~ s/^\s+$//g;   #ADDED 20010514 - COMPLETELY BLANK EMPTY LINES.
		#$lines[$i] = ("\t" x $current_indent) . $lines[$i];
#print "- ci=$current_indent= cont=$cont= lines($i)=$lines[$i]=\n";
	}
	$textScrolled[$activeWindow]->markSet('insert',$selstart);
	$textScrolled[$activeWindow]->delete($selstart, $selend);
	$wholething = join("\n",@lines) . "\n";
	$textScrolled[$activeWindow]->insert('insert',$wholething);
	$textScrolled[$activeWindow]->markSet('insert',$curposn);
	$statusLabel->configure(-text=>"..Realligned.");
}

1
