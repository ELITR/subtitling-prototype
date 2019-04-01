#!/usr/bin/env perl
# full screen, escape to exit
# mplayer tv:// tv=driver=v4l2:input=1:width=768:height=576:device=/dev/video0:audiorate=0
use strict;
use Getopt::Long;
use Tk;
use Tk::Wm;
use X11::Xlib ':all';
use POSIX ":sys_wait_h";


use X11::Protocol;
my $X = X11::Protocol->new();

my $font = "-*-fixed-bold-*-*-*-18-*-*-*-*-*-iso10646-*";

my $reparent_window = shift;
my $display = X11::Xlib::XOpenDisplay($ENV{"DISPLAY"});

my $guest_area_h = 720;
my $guest_area_w = 1280;
my $guest_roi_to_crop = "960:714:160:0";
$guest_roi_to_crop = "1280:720:0:0";

my $cameraid = 0;
my $attempt_fullscreen = 1;
my %children = ();
my $pane_background = '#000000';
$pane_background = '#00aa00';

sub videocommand {
  my $reparent_into_windowid = shift;
  my $croprect = shift;

  # Options to crop:
  # ffplay -i input.mp4 -vf "crop=in_w:in_h-25:0:0"
  # ffplay -i input.mp4 -vf "crop=in_w-25*16/9:in_h-25:(ow-iw)/2:0"
  #
  # Crop in ffmpeg and play with mplayer which can be embedded:
  # ffmpeg -i /dev/video0 -vf crop=100:100:12:34 -f avi pipe:1 | mplayer -
 # return "vlc /ha/home/bojar/public_html/elitr-kickoff-recordings/elitr-day1-hd-try2.mp4";

  my $useinput = "/dev/video$cameraid";

  if (defined $croprect) {
    # Crop in ffmpeg and play with mplayer which can be embedded:
    $useinput = "/ha/home/bojar/public_html/elitr-kickoff-recordings/elitr-day1-hd-try2.mp4" if ! -e $useinput;
    return "ffmpeg -i $useinput -vf crop=$croprect -f avi pipe:1 | mplayer -wid $reparent_into_windowid -"
  } else {
    # Direct play with mplayer:
    if (-e $useinput) {
      return "mplayer -wid $reparent_into_windowid tv:// tv=driver=v4l2:input=1:device=".$useinput.":audiorate=0";
    } else {
      return "mplayer -wid $reparent_into_windowid /ha/home/bojar/public_html/elitr-kickoff-recordings/elitr-day1-hd-try2.mp4";
    }
    # more options possible:
    # return "mplayer -wid $reparent_into_windowid tv:// tv=driver=v4l2:input=1:width=768:height=576:device=/dev/video0:audiorate=0";
  }
}


sub spawn {
  my $command = shift;
  print "SPAWN: $command\n";
  defined(my $childpid = fork) or die "$0: fork: $!\n";
  if (!$childpid) {
      exec $command;
      die "$0: failed to exec '$command': $!\n";
  }
  print "  GOT PID: $childpid\n";
  # remember the child
  $children{$childpid} = 1;
  # remember all grandchildren
  # for my $p ({new Proc::ProcessTable->table}){
    # push @children, $p->pid if $p->ppid == $childpid;
  # }
  return $childpid;
}
sub killchild {
  my $pid = shift;
  print "KILLING $pid\n";
  kill 'INT', $pid; sleep(1);
  system("pkill -9 -s $pid"); sleep(1);
  kill 'KILL', $pid;
}

my $mw = MainWindow->new(
            -background=>'#000000',
            -title=>"You Should Never See This.");


# die if any important child dies
$SIG{CHLD} = sub {
    my $important_child = 0;
    while ((my $child = waitpid(-1, WNOHANG)) > 0) {
        $important_child = 1 if $children{$child};
        print STDERR "SOLVING SIGCHILD, got Kid_Status{$child} = $?\n";
    }
    $mw->destroy() if $important_child;
};

sub make_pane {
  my $geometry = shift;
  my $pane = $mw->Toplevel(
            -background=>$pane_background,
            -title=>"You Should Never See This.");
  $pane->transient($mw);
  $pane->resizable(0, 0);
  $pane->geometry($geometry);
  $pane->overrideredirect(1) if $attempt_fullscreen;
  $pane->MapWindow();
  return $pane;
}

## Two bad options for fullscreen no decorations:
# $mw->FullScreen(1);
# $mw->grabGlobal;
# $mw->focusForce;

$mw->overrideredirect(1) if $attempt_fullscreen;
$mw->focusmodel("active") if $attempt_fullscreen;

my $screenheight = $mw->screenheight();
my $screenwidth = $mw->screenwidth();
print STDERR "$screenheight x $screenwidth\n";
#$display_window->overrideredirect(0);
$mw->geometry($screenwidth."x".$screenheight."+0+0");
$mw->geometry("100x".$screenheight."+0+0");


$mw->resizable(0, 0);

# $vw->deiconify();
# $vw->raise();


$mw->bind('all' => '<Key-Escape>' => sub {$mw->destroy();});
$mw->MapWindow();

my $bottombar_h = 100;
my $video_h = $screenheight - $bottombar_h;
my $video_w = $screenwidth;
my $video_xoff = 0;

my $videopane = make_pane("${video_w}x${video_h}+$video_xoff+0");
my $videopid = spawn(videocommand($videopane->id(), $guest_roi_to_crop));

my $xtermpane = make_pane("${screenwidth}x${bottombar_h}+0-0");
my $xtermpid;

grab_it("lecture-translator.kit.edu", $xtermpane);

# if (defined $reparent_window) {
#   # only use the given window ID to reparent it here
#   my $reparent_window_int = hex($reparent_window);
#   my $pane_int = hex($mw->id())+2;
#   print STDERR "Trying to reparent window $reparent_window ($reparent_window_int) into ".$xtermpane->id()." ($pane_int, ".sprintf("%08x", $pane_int)."), display: $display\n";
#   XReparentWindow($display, $reparent_window_int, $pane_int, 0,0);
# } else {
#   # run our xterm
#   $xtermpid= spawn("xterm -fn '$font' -fb '$font' -into ".$xtermpane->id().' -e "while true; do date; sleep 5; done"');
# }

$mw->focusForce();

MainLoop;
  # system("ps --forest -o pid,tty,stat,time,cmd -g $childpid");

system("killall mplayer");
foreach my $pid (keys %children) {
  killchild($pid);
}




sub grab_it {
    my $winname = shift;
    my $pane = shift;
    my $wid;
    my $check = $pane->repeat(50, sub {
        $wid = get_window_by_name($winname);
            });
     
    while (!defined $wid) {
        $pane->waitVariable(\$wid);
    }
    $check->cancel;
     
    die "Failed to find window $winname." if !$wid;

    my $tgtid = $pane->id();
    my $widx = "0x".sprintf("%08x", $wid);
    print STDERR "Reparenting $wid ($widx) into $tgtid ($pane, ".$pane->id().")\n";
    $X->ReparentWindow($widx, $tgtid, 0, 0);
      # this does not work on Ubuntu 16.04
    # system("xdotool windowmove $widx ");
    my $mydesk = `xdotool get_desktop_for_window $tgtid`;
    print STDERR "MY DESK: $mydesk\n";
    system("xdotool set_desktop_for_window $widx $mydesk");
    #system("xdotool windowactivate --sync $widx");
    system("xdotool windowunmap --sync $widx");
    system("xdotool windowsize --sync $widx ".$pane->width." ".$pane->height);
    system("xdotool windowmove --sync $widx ".$pane->rootx." ".$pane->rooty);
    system("xdotool set_window --overrideredirect 1 $widx");
    # ensure same desktop
    system("xdotool windowmap --sync $widx");
    system("xdotool windowactivate --sync $widx");
    # system("xdotool windowreparent $widx $tgtid");
      # this is very dangerous, damages the google-chrome window
    print STDERR "Reparented\n";
}
 
sub get_window_by_name {
    _get_window_by_name($X->{'root'}, $_[0]);
}
 
sub _get_window_by_name {
    my($root, $searchname) = @_;
    my(undef, undef, @new_kids) = $X->QueryTree($root);
    foreach my $k (@new_kids) {
        my $atomnr;
        foreach my $atom ($X->ListProperties($k)) {
            if ($X->GetAtomName($atom) eq "WM_CLASS") {
               $atomnr = $atom;
               last;
            }
        }
    if (defined $atomnr) {
        my($classprop) = $X->GetProperty($k, $atomnr, "AnyPropertyType",0, 256, 0);
        my($class, $name) = split(/\0/, $classprop);
        print STDERR "Considering '$class' eq '$searchname'\n";
        if ($class eq $searchname) {
            print STDERR "  Found $k\n";
            return $k;
        }
    }
    my $ret = _get_window_by_name($k, $searchname);
    if (defined $ret) {
        return $ret;
    }
    }
    undef;
}

