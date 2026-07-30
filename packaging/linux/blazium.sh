# Blazium Hub + CLI environment (installed to /etc/profile.d/blazium.sh)
export BLAZIUM=/opt/blazium
case ":${PATH}:" in
  *":${BLAZIUM}/bin:"*) ;;
  *) export PATH="${BLAZIUM}/bin:${PATH}" ;;
esac
