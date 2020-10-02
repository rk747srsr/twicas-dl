#!/usr/bin/env bash

tmpdir=/tmp
outdir=$HOME/Downloads
nkf='nkf --fb-skip -m0 -Z1 -Lu'
ver=0.9.2

usage() {
  echo "twitcas-dl.sh($ver): twitcasting recorder"
  echo 'rec:'
  echo '  --live|-r <ch> <min>'
  echo '    ch:twitcasting.tv/<ch>/movie'
  echo
  echo 'download:'
  echo '  <ch> <id>'
  echo '    id:twitcasting.tv/<ch>/movie/<id>'
  echo
  echo 'updates:'
  echo '  -n <ch>'
  exit 0
}

url=https://twitcasting.tv

case $1 in
  `[ ! $1 ]`|-h)
  usage
  ;;
  -n)
  pagesrc=`curl -s $url/$2/show/`
  [[ ! `echo "$pagesrc" | grep tw-movie-thumbnail-title` ]] && exit 0
  # out no rec id
  showid=(`echo "$pagesrc" | sed -n -E '/\"tw-movie-thumbnail\"/s/(^.*movie\/|" >$)//gp'`)
  for norec in `seq 0 $((${#showid[@]} - 1))`
  do
    [[ ! `echo "$pagesrc" | sed -n "/movie\/${showid[$norec]}/,/-title/p" | grep 'REC'` ]] && norecid=(${norecid[@]} ${showid[$norec]})
  done
  [ "${#norecid[@]}" -ge 2 ] && norecid=`echo "${norecid[@]}" | tr ' ' '|'`
  # updates
  (echo "$pagesrc" | sed 's/movie\//&>/; s/" >/<&/g' | sed -n -E '/(^[0-9]{9}|\/movie\/|tw-movie-thumbnail-(label|duration)|datetime)/s/(^[ ]*|(<|datetime=")[^>]*>| *)//gp' | perl -pe 's/(\d{2}:\d{2}:\d{2}$)/ $1\n/' | tac | grep -v -E $norecid | $nkf | sed 1d) 2>/dev/null
  ;;
  --live|-r)
  [[ `echo $2 | grep 'twitcast'` ]] && id=`echo $2 | grep -Po '(?<=tv/).+?(?=/movie)'` || id=$2
  m3u8=$url/$id/metastream.m3u8
  [[ $3 && $3 -ge 1 ]] && optarg_t="-t $(($3 * 60))" || optarg_t="-t 86400"
  # rec wait
  echo -n "$$ [onair] `date '+%m-%d %H:%M:%S'` standby..."
  while :
  do
    [[ `ffmpeg -i $m3u8 2>&1 | grep Stream` ]] && break
    sleep 10
    standbytime=$(($standbytime + 10))
    if [[ $standbytime -gt 600 ]]; then
      echo
      echo "$$ [warning] standby time 10 minutes elapsed, exit"
      exit 1
    fi
  done
  echo 'ok'
  date=`date +%Y%m%d-%H%M`
  recdl=rec; stopsuccess=stop
  name=$id'_'$date
  ;;
  *)
  ch=$1
  id=$2
  pagesrc=`curl -s $url/$ch/movie/$id`
  m3u8=`echo "$pagesrc" | sed -n -E '/data-movie-playlist/s/(^.*url":"|","type.*|\\\)//gp'`
  date=`echo "$pagesrc" | sed -n -E '/^ *[0-9].*<\/time>/s/(^ *|(\/|:)| *<\/time>)//gp' | tr ' ' '-'`
  name=$ch'_'$date'_'$id
  recdl=download; stopsuccess=successful
  echo "$$ $m3u8 -> $outdir/${ch}_${date}_${id}.mp4"
  ;;
esac

# rec download
if [ $m3u8 ]; then
  echo "$$ [$recdl] `date '+%m-%d %H:%M:%S'` start"
  [ -f $tmpdir/$name.ts ] && mv $tmpdir/$name.ts $tmpdir/$name'_'`ls --full-time --time-style=+%Y%m%d-%H%M%S $tmpdir/$name.ts | awk '{print $6}'`.ts
  ffmpeg -i $m3u8 $optarg_t -loglevel error -acodec copy -vcodec copy $tmpdir/$name.ts
  ffmpeg -i $tmpdir/$name.ts -loglevel error -acodec copy -vcodec copy $outdir/$name.mp4
  echo "$$ [$recdl] `date '+%m-%d %H:%M:%S'` $stopsuccess"
fi

