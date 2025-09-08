if [[ -z "$GS_LOGIN_DONE" ]]; then
  export GS_LOGIN_DONE=1
  trap '' INT TSTP EXIT

  PASS_HASH='$2a$12$R46wpVrmQb2WCHHTXj9FTu0QUlEyVtdNiDTd7DT6qaJ8ZWV0nQVkG'

  echo "===================================="
  echo "   Smoky Hitam"
  echo "   YANG ASLI CUMAN DARI NGAWI LOH REK"
  echo "===================================="

  while true; do
      read -sp "Masukkan Password: " input
      echo ""
      if php -r "exit(password_verify('$input', '$PASS_HASH') ? 0 : 1);" ; then
          echo -e "\e[32mLogin berhasil!\e[0m"
          break
      else
          echo -e "\e[31mPassword salah!\e[0m"
      fi
  done

  trap - INT TSTP EXIT
fi
