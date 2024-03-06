#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#ConfFile
iptables_conf='/root/iptables.config.sh'
function root_ness() {
  if [[ $EUID -ne 0 ]]; then
    echo "The script needs to be run with ROOT privileges!"
    exit 1
  fi
}
function conf_list() {
  cat $iptables_conf
}
function conf_add() {
  if [ ! -f $iptables_conf ]; then
    echo "Configuration file not found!"
    touch $iptables_conf
  fi
  echo "Please enter the private network IP of the VM"
  read -p "(Default: Exit):" confvmip
  [ -z "$confvmip" ] && exit 1
  echo
  echo "VM intranet IP = $confvmip"
  echo
  while true; do
    echo "Please enter the port of the VM:"
    read -p "(Default: 22):" conf_vm_port
    [ -z "$conf_vm_port" ] && conf_vm_port="22"
    expr $conf_vm_port + 0 &>/dev/null
    if [ $? -eq 0 ]; then
      if [ $conf_vm_port -ge 1 ] && [ $conf_vm_port -le 65535 ]; then
        echo
        echo "VM port = $conf_vm_port"
        echo
        break
      else
        echo "Typo, port range should be 1-65535!"
      fi
    else
      echo "Typo, port range should be 1-65535!"
    fi
  done
  echo
  while true; do
    echo "Please enter the host port"
    read -p "(Default port: 8899):" nat_conf_port
    [ -z "$nat_conf_port" ] && nat_conf_port="8899"
    expr $nat_conf_port + 0 &>/dev/null
    if [ $? -eq 0 ]; then
      if [ $nat_conf_port -ge 1 ] && [ $nat_conf_port -le 65535 ]; then
        echo
        echo "host port = $nat_conf_port"
        echo
        break
      else
        echo "Typo, port range should be 1-65535!"
      fi
    else
      echo "Typo, port range should be 1-65535!"
    fi
  done
  echo "Please enter forwarding protocol:"
  read -p "(tcp or udp ,Enter default operation: exit):" conftype
  [ -z "$conftype" ] && exit 1
  echo
  echo "protocol type = $conftype"
  echo
  iptables_shell="iptables -t nat -A PREROUTING -i vmbr0 -p $conftype --dport $nat_conf_port -j DNAT --to-destination $confvmip:$conf_vm_port"
  if [ $(grep -c "$iptables_shell" $iptables_conf) != '0' ]; then
    echo "Configuration already exists"
    exit 1
  fi
  get_char() {
    SAVED_S_TTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty $SAVED_S_TTY
  }
  echo
  echo "Enter continue, Ctrl+C exit"
  char=$(get_char)
  echo $iptables_shell >>$iptables_conf
  run_return=$($iptables_shell)
  echo $run_return
  echo 'Configuration added successfully'
}
function add_confs() {
  root_ness
  conf_add
}
function del_conf() {
  echo
  while true; do
    echo "Please enter the host port:"
    read -p "(Default: exit):" confserverport
    [ -z "$confserverport" ] && exit 1
    expr $confserverport + 0 &>/dev/null
    if [ $? -eq 0 ]; then
      if [ $confserverport -ge 1 ] && [ $confserverport -le 65535 ]; then
        echo
        echo "host port = $confserverport"
        echo
        break
      else
        echo "Typo, port range should be 1-65535!"
      fi
    else
      echo "Typo, port range should be 1-65535!"
    fi
  done
  echo
  iptables_shell_del=$(cat $iptables_conf | grep "dport $confserverport")
  if [ ! -n "$iptables_shell_del" ]; then
    echo "There is no port for this host in the configuration file"
    exit 1
  fi
  iptables_shell_del_shell=$(echo ${iptables_shell_del//-A/-D})
  run_return=$($iptables_shell_del_shell)
  echo $run_return
  sed -i "/$iptables_shell_del/d" $iptables_conf
  echo 'Configuration deleted successfully'
}
function del_confs() {
  printf "Are you sure you want to delete the configuration? operation is irreversible(y/n) "
  printf "\n"
  read -p "(default: n):" answer
  if [ -z $answer ]; then
    answer="n"
  fi
  if [ "$answer" = "y" ]; then
    root_ness
    del_conf
  else
    echo "Configuration delete operation canceled"
  fi
}
action=$1
case "$action" in
add)
  add_confs
  ;;
list)
  conf_list
  ;;
del)
  del_confs
  ;;
*)
  echo "Parameter error! [${action} ]"
  echo "usage: $(basename $0) {add|list|del}"
  ;;
esac
