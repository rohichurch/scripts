#!/bin/bash

# This script is used for preparing the weekly MP3 sermon.
# Run this script after the sermon has been editted and
# exported to the $DEFAULT_SONGS_DIR.
#
# The script will take care of:
#   1) Converting the WAV file to MP3
#   2) Embedding the sermon details into the MP3
#   3) Uploading the MP3 to Amazon AWS bucket
#
# Once completed, a link to the MP3 file on Amazon AWS will
# be provided which will then be used for adding the sermon
# to the church's website.

NOTIFICATION_ADDRESS="devops-team@rohichurch.org,jonathan@rohichurch.org,rene@rohichurch.org"

CURRENT_YEAR=$(date +"%Y")
DEFAULT_SONGS_DIR="$HOME/Desktop/Mixdowns"
LAST_WAV_FILE_ADDED=$(ls -td $DEFAULT_SONGS_DIR/*.aif | head -1)
DROPBOX_SERMON_DIR="$HOME/Dropbox/Sermons"
AWS_S3_PODCASTS_DIR="podcasts/${CURRENT_YEAR}/"
AWS_S3_PODCAST_BUCKET="s3://rohichurch/${AWS_S3_PODCASTS_DIR}"

function banner {
  echo -en "\033[0;34m==> "; tput sgr0
  echo $1
}

function get_sermon_info {
  read -p "Enter the speaker's name: " SPEAKER_NAME
  read -p "Enter the sermon title: " SERMON_TITLE
  SERMON_MP3_FILENAME="${SPEAKER_NAME} -"

  read -p "Is this sermon part of a series? [y/n]: " IS_SERIES
  if [[ $IS_SERIES =~ ^y ]] ; then
    read -p "Enter sermon series name: " SERMON_SERIES
    SERMON_MP3_FILENAME="${SERMON_MP3_FILENAME} ${SERMON_SERIES} -"
    read -p "What number is this in the series?: " TRACK_NUMBER
    TRACK_NUMBER=$( printf "%02d" ${TRACK_NUMBER} )
    SERMON_MP3_FILENAME="${SERMON_MP3_FILENAME} ${TRACK_NUMBER} -"
  fi
  SERMON_MP3_FILENAME="${SERMON_MP3_FILENAME} ${SERMON_TITLE}.mp3"
  SERMON_MP3_FILENAME=$( echo ${SERMON_MP3_FILENAME} | tr -d '?' )
}

function convert_to_mp3 {
  if [[ $IS_SERIES =~ ^y ]] ; then
  	lame \
  	  -b 64 \
  	  --tt "${SERMON_TITLE}" \
  	  --ta "${SPEAKER_NAME}" \
  	  --tl "${SERMON_SERIES}" \
  	  --ty  ${CURRENT_YEAR} \
  	  --tc "Copyright ${CURRENT_YEAR}, Rohi Christian Church" \
  	  --tn ${TRACK_NUMBER} \
  	  --tg "Sermons" \
  	  --ti "${DROPBOX_SERMON_DIR}/album-cover_current-series.jpg" \
          --add-id3v2 \
  	"${1}" "$DROPBOX_SERMON_DIR/${2}"
  else
  	lame \
  	  -b 64 \
  	  --tt "${SERMON_TITLE}" \
  	  --ta "${SPEAKER_NAME}" \
  	  --tl "Rohi Christian Church" \
  	  --ty  ${CURRENT_YEAR} \
  	  --tc "Copyright ${CURRENT_YEAR}, Rohi Christian Church" \
  	  --tg "Sermons" \
  	  --ti "${DROPBOX_SERMON_DIR}/album-cover_rohi-logo.jpg" \
  	  --add-id3v2 \
  	"${1}" "$DROPBOX_SERMON_DIR/${2}"
  fi

}

function upload_to_s3 {
  aws s3 cp "${1}" ${AWS_S3_PODCAST_BUCKET} --grants \
    read=uri=http://acs.amazonaws.com/groups/global/AllUsers \
    full=emailaddress=alex@rohichurch.org
}

function get_podcast_aws_url {
  local aws_sermon_filename=$(echo ${SERMON_MP3_FILENAME} | sed -e 's/ /+/g')
  echo "http://rohichurch.s3.amazonaws.com/${AWS_S3_PODCASTS_DIR}${aws_sermon_filename}"
}

function send_email_notification {
  local notification_address=$1
  local sermon_title=$2
  local speaker_name=$3
  local mp3_location=$4
  mail -s "Podcast Uploaded: ${sermon_title}" ${notification_address} <<EOF
  A new podcast has been uploaded.

   * Title: ${sermon_title}
   * Speaker: ${speaker_name}
   * MP3 Location: ${mp3_location}

  To add the message to the Rohi Christian Church podcast, open
  http://www.rohichurch.org/admin and add go to Sermons > Add New
EOF
}

get_sermon_info

banner "Converting AIFF file to MP3..."
banner "${LAST_WAV_FILE_ADDED}"
convert_to_mp3 "${LAST_WAV_FILE_ADDED}" "${SERMON_MP3_FILENAME}"
banner "Done converting."

banner "Uploading to Amazon AWS..."
upload_to_s3 "${DROPBOX_SERMON_DIR}/${SERMON_MP3_FILENAME}"
banner "Done uploading."

MP3_LOCATION=$(get_podcast_aws_url)

banner "Open http://www.rohichurch.org/admin and add go to Sermons > Add New"
banner "Location of MP3: ${MP3_LOCATION}"

send_email_notification \
  "${NOTIFICATION_ADDRESS}" \
  "${SERMON_TITLE}" \
  "${SPEAKER_NAME}" \
  "${MP3_LOCATION}"

exit 0
