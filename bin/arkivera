if [ "$#" -ne 1 ]; then
   echo "Usage: $0 <destination>"
   exit 1
fi

DEST=$1

if [ ! -d "$DEST" ]; then
	echo "Destination directory doesn't exist"
	exit 1
fi

function do_rsync {
	/usr/local/bin/rsync --iconv utf-8-mac,utf-8 -av -e ssh "pi:$1" "$DEST"
	if [ $? -ne 0 ]; then
		exit 1
	fi
}

do_rsync /media/hddb/Foto
do_rsync /media/hddb/Dokument
do_rsync /media/hddb/Musik
do_rsync /media/hddb/Projekt
