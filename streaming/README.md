## Basic Setup

1. Install nginx
2. Change the config to support RTMP
3. Run ffmpeg to stream (the screen, for now; later I should be streaming the videomixer/webcam)
4. In a separate terminal, run ffplay to watch it (this needs to happen on a different machine and via a HTML stream viewer in fact)

### Install

Follow this:
https://opensource.com/article/19/1/basic-live-video-streaming-server

But compile nginx from source so that RTMP is supported
https://stackoverflow.com/questions/37442819/unknown-directive-rtmp-in-etc-nginx-nginx-conf76

Allow RTMP in nginx config file.
See my: ``sample-nginx.conf``


### Launch
```
sudo /usr/local/nginx/sbin/nginx
```

### Streaming and Watching

```
ffmpeg -f x11grab -r 30 -i ":0.0" -deinterlace -vcodec libx264 -pix_fmt yuv420p -preset medium -g 60 -b:v 1000k -threads 6 -qscale 3 -bufsize 2000k -f flv rtmp://localhost/live/tabvn
```

Watching:
```
ffplay -probesize 500 rtmp://localhost/live/tabvn
```

This has the delay of about 3-4 seconds, the default has a lag of 10 seconds.

## Other Interesting Observations

It is possible to show audio waves with ffplay:
ffplay -showmode 1 ~bojar/diplomka/granty/elitr/cruise-control/sup-for-testing-at-mock-interpreted-conferences-CUNI-FF/sample-english-speech.wav
