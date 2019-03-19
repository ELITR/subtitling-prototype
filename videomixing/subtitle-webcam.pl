#!/usr/bin/env perl
# full screen, escape to exit
# mplayer tv:// tv=driver=v4l2:input=1:width=768:height=576:device=/dev/video0:audiorate=0
use strict;
use Getopt::Long;
use Tk;
use Tk::Wm;
use POSIX ":sys_wait_h";

my $attempt_fullscreen = 1;
my %children = ();
my $pane_background = '#000000';

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

  my $useinput = "/dev/video0";

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

my $height = $mw->screenheight();
my $width = $mw->screenwidth();
print STDERR "$height x $width\n";
#$display_window->overrideredirect(0);
$mw->geometry($width."x".$height."+0+0");


$mw->resizable(0, 0);

# $vw->deiconify();
# $vw->raise();


$mw->bind('all' => '<Key-Escape>' => sub {$mw->destroy();});
$mw->MapWindow();

my $videopane = make_pane("900x600+100+50");
# video with cropping:
# my $videopid = spawn(videocommand($videopane->id(), "200:100:50:10"));
my $videopid = spawn(videocommand($videopane->id(), undef));

my $xtermpane = make_pane($width."x150+0-0");
my $xtermpid = spawn('xterm -into '.$xtermpane->id().' -e "while true; do date; sleep 5; done"');

# sleep 30;
# 
# # find all my children
# my @children;
# for my $p ({new Proc::ProcessTable->table}){
#   push @children, $p->pid if $p->ppid == $$;
# }


$mw->focusForce();

system("ps --forest -o pid,tty,stat,time,cmd -g $$");

MainLoop;
  # system("ps --forest -o pid,tty,stat,time,cmd -g $childpid");

system("killall mplayer");
foreach my $pid (keys %children) {
  killchild($pid);
}

