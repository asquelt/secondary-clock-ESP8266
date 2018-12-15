function set_wait() {
  ./set_color.sh $1 $2 $3 $4
  sleep 3
}

set_wait $1 255 0 0
set_wait $1 0 255 0
set_wait $1 0 0 255
set_wait $1 0 255 255
set_wait $1 255 255 0
set_wait $1 255 0 255
set_wait $1 255 255 255
set_wait $1 0 0 0
