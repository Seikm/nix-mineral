{
  l,
  cfg,
  ...
}:

{
  options = {
    bluetooth-kmodules = l.mkBoolOption ''
      Enable bluetooth related kernel modules.
    '' true;
  };

  config = l.mkIf (!cfg) {
    environment.etc."modprobe.d/nm-disable-bluetooth.conf" = {
      text = ''
        install bluetooth /usr/bin/disabled-bluetooth-by-security-misc
        install bluetooth_6lowpan  /usr/bin/disabled-bluetooth-by-security-misc
        install bt3c_cs /usr/bin/disabled-bluetooth-by-security-misc
        install btbcm /usr/bin/disabled-bluetooth-by-security-misc
        install btintel /usr/bin/disabled-bluetooth-by-security-misc
        install btmrvl /usr/bin/disabled-bluetooth-by-security-misc
        install btmrvl_sdio /usr/bin/disabled-bluetooth-by-security-misc
        install btmtk /usr/bin/disabled-bluetooth-by-security-misc
        install btmtksdio /usr/bin/disabled-bluetooth-by-security-misc
        install btmtkuart /usr/bin/disabled-bluetooth-by-security-misc
        install btnxpuart /usr/bin/disabled-bluetooth-by-security-misc
        install btqca /usr/bin/disabled-bluetooth-by-security-misc
        install btrsi /usr/bin/disabled-bluetooth-by-security-misc
        install btrtl /usr/bin/disabled-bluetooth-by-security-misc
        install btsdio /usr/bin/disabled-bluetooth-by-security-misc
        install btusb /usr/bin/disabled-bluetooth-by-security-misc
        install virtio_bt /usr/bin/disabled-bluetooth-by-security-misc
      '';
    };
  };
}
