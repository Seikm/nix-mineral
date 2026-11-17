# This file is part of nix-mineral (https://github.com/nix-community/nix-mineral/).
# Copyright (c) 2025 cynicsketch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

{
  l,
  cfg,
  ...
}:

{
  options = {
    mptcp = l.mkBoolOption ''
      Control whether Multipath TCP (mptcp) is enabled.

      mptcp allows applications connections to be split over multiple network
      interfaces or paths. This is primarily useful for mobile applications, as
      it allows transitioning between networks without abrupt termination.

      mptcp has history of security vulnerabilities and is disabled by default.

      ::: {.note}
      Additional reference:
      - https://www.rfc-editor.org/info/rfc8684/
      - https://github.com/secureblue/secureblue/commit/58f9fd5f7f63f0a4209306ee507c4f5c53e3023a
      - https://nvd.nist.gov/vuln/detail/cve-2026-98432
      - https://nvd.nist.gov/vuln/detail/cve-2026-80586
      - https://nvd.nist.gov/vuln/detail/cve-2026-80587
      - https://nvd.nist.gov/vuln/detail/cve-2026-84784
      - https://nvd.nist.gov/vuln/detail/cve-2026-89554
      :::
    '' false;
  };

  config = l.mkIf (!cfg) {
    boot.kernel.sysctl = {
      "net.mptcp.enabled" = l.mkDefault "1";
    };
  };
}
