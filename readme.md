KxTorrent is a torrent (bittorrent) client for iPhone. 
======================================================

### Build instructions:
	
First, you need update submodules.
For this open console and type in

	cd kxtorrent
	git submodule update --init	--recursive

Then, build ffmpeg

	cd submodules/kxmovie	
	rake build_ffmpeg

After that, you can build and run SwarmLoader target.


### Features:

- play media (video and audio)
- multiple torrent downloading
- rate control (limit upload/download speed)
- blacklist 
- integrated web browser
- bookmark manager
- download .torrent files with help of integrated web browser
- able to add .torrent via itunes file sharing
- share a content via itunes file sharing
- integrated file browser
- supports video formats: .avi .mkv .mpeg .mpg .flv .vob .m4v .3gp .mp4 .mov 
- supports audio formats: .ogg .mpga .mka .mp3 .wma .m4a
- supports other formats: .png .jpg .gif .tiff .pdf .txt

### Requirements

at least iOS 5.1 and iPhone 3GS 

### Screenshots:

![main](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/main.png "Main")
![detail](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/detail.png "Detail")
![pieces](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/pieces.png "Pieces")
![file browser](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/filebrowser.png "File Browser")
![web browser](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/webbrowser.png "Web Browser")
![settings](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/settings.png "Settings")
![download .torrent](https://raw.github.com/kolyvan/kxtorrent/master/screenshots/downloadtorrentfile.png "Download .torrent")


### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).

### Download

Apple rejects any bittorent app from app store. 
But you can download [.ipa](http://dl.dropbox.com/u/80472203/SwarmLoader.ipa) and run it on jailbroken device. 

