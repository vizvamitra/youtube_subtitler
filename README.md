#YOUTUBE SUBTITLER

##INFO

Youtube subtitler is a **Ruby** script that could help you to download subtitles for single or many youtube videos at once.

All subtitles files would be saved in a new directory named `subtitles_TIMESTAMP`, where TIMESTAMP is a sequence of digits. You can specify a path where this directory would be created.

Script allows you to choose prefered language of subtitles (yet youtube could not have this language) using the `-l` key.

You can also specify the key `-c` (or `--collect`) in order to tell the script to save all subtitles in one file `all_subtitles.txt`.

If an error occures with any of given links, script will log these links to file `subtitles_TIMESTAMP/errors.log` so you can correct your links or perhaps choose another language and give this links to the script again using ` < errors.log`

##USAGE

	youtube_subtitler.rb [OUTPUT_DIR, -c, -lLANG] LINKS

	  LINKS

	  		Whitespace-separated list of youtube links

	  OUTPUT_DIR

	  		Directory where to create output files

	  -lLANG

	  		Allows to specify desired subtitles language (LANG)

	  -c, --collect

	  		Collect all subtitles in one file "all_subtitles.txt"

##EXAMPLES

	ruby youtube_subtitler.rb -c -len < linklist.txt
	ruby youtube_subtitler.rb -les-ES http://youtu.be/e7Fr_sdE4M0
	ruby youtube_subtitler.rb ~/videos/youtube -c http://youtu.be/e7Fr_sdE4M0

##CREDITS

Made for you by **Vizvamitra** (vizvamitra@gmail.com, Russia)

Special thanks to **Dmitry** aka **Blackbird~**