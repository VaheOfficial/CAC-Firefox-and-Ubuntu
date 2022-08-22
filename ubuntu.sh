#!/bin/bash

#####
# This script does the folowing
# Check for root and install script dependencies
# 1. Download and install DoD Certs
# 2. Check for and install PKCS#11 libraries (e.g. OpenSC)
# 3. Install VMWare Horizon

# shellcheck disable=SC2086

#Check if Root
echo -e "\n[INFO] Checking effective user id.";
if [[ $EUID -ne 0 ]]; then
    echo -e "\n[FAIL] Script must be run with sudo or as root; exiting." 1>&2;
    exit 1;
else
    echo -e "\n[INFO] Effective user id is zero (i.e. root or sudo user); proceeding with install.";
fi

# Check dependencies
DEPS=("python2.7" "tar" "coreutils" "wget" "binutils" "libxkbfile1" "libatk-bridge2.0-0" "libgtk-3-0" "libxss1" "openssl" "unzip" "libnss3-tools")
MISSINGDEPS=()

for i in "${DEPS[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$i" 2>/dev/null | grep -q "ok installed"; then
    MISSINGDEPS+=("$i")
  else
    echo -e "$i installed"
  fi
done

if (( ${#MISSINGDEPS[@]} > 0 )); then
  echo -e "\n[INFO] Missing dependencies ${MISSINGDEPS[*]}"
  if [[ "$1" == "-y" ]]; then
    echo -e "\n[INFO] Installing..."
    sudo apt update && sudo apt install -y ${MISSINGDEPS[*]};
  else
    read -rp "[INFO] Would you like to install them? [Y/n] ";
    if [[ $REPLY == [yY] ]]; then
      echo -e "\n[INFO] Installing..."
      sudo apt update && sudo apt install -y ${MISSINGDEPS[*]};
    else
      echo -e "\n[FAIL] Not installing dependencies; exiting." 1>&2;
      exit 1;
    fi
  fi
fi

# 1. Download and install DoD Certs

{ echo -e "\n[INFO] Determining if DoD certificate installation is required." && \
  wget -S --spider --timeout 10 https://afrcdesktops.us.af.mil && \
  echo -e "\n[INFO] Desktop Anywhere login gateway is accessible; DoD certificate installation is not required." && \
  cert_install_required=false; } || \
{ echo -e "\n[INFO] Desktop Anywhere login gateway is not accessible; DoD certificate installation is required.";
  cert_install_required=true; };
if ${cert_install_required}; then
    cert_dir="/usr/local/share/ca-certificates/dod/";
    { mkdir -p .certs/dod/ || { echo -e "\n[FAIL] Failed to make certs sub-directory tree; exiting."; exit 1; } } && \
    { echo -e "\n[INFO] Fetching latest DoD CA Bundles." && \
      wget -O .certs/dod.zip https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/certificates_pkcs7_DoD.zip && \
      echo -e "\n[INFO] Successfully fetched latest DoD CA Bundle."; } || \
      { echo -e "\n[FAIL] Failed to fetch latest DoD CA Bundle; exiting." 2>&1; \
        exit 1; } && \
    { echo -e "\n[INFO] Extracting DoD certificates into a temp sub-directory."
      unzip -o .certs/dod.zip -d .certs/dod/; } || \
      { echo -e "\n[FAIL] Failed to extract DoD certificates into certs sub-directory; exiting." 2>&1; \
        exit 1; } && \
    { cd .certs/dod/* || { echo -e "\n[FAIL] Failed to cd into DoD certs sub-directory; exiting."; exit 1; } } && \
    { echo -e "\n[INFO] Verifying DoD certificate checksums." && \
      openssl smime -no_check_time -verify -in ./*.sha256 -inform DER -CAfile ./*.pem | \
      while IFS= read -r line; do
	  echo "${line%$'\r'}";
      done | \
      sha256sum -c; } || \
      { echo -e "\n[FAIL] File checksums do not match those listed in the checksum file; exiting." 2>&1; \
        exit 1; } && \
    { mkdir -p ${cert_dir} || \
    { echo -e "\n[FAIL] Failed to make dod sub-directory (${cert_dir}); exiting." 1>&2; exit 1; } };
    echo -e "\n[INFO] Converting DoD certificates to plaintext format and staging for inclusion in system CA trust.";
    for p7b_file in *.pem.p7b; do
        pem_file="${p7b_file//.p7b/}"
        { echo -e "\n[INFO] Converting ${p7b_file} to ${pem_file}" && \
          openssl \
              pkcs7 \
                  -in "${p7b_file}" \
                  -print_certs \
                  -out "${pem_file}";} || \
        { echo -e "\n[FAIL] Failed to convert ${p7b_file} to ${pem_file}; exiting." 1>&2; \
          exit 1; } && \
	echo -e "\n[INFO] Splitting CA bundle file (${pem_file}) into individual cert files and staging for inclusion in system CA trust." && \
 	while read -r line; do
 	   if [[ "${line}" =~ END.*CERTIFICATE ]]; then
 	       cert_lines+=( "${line}" );
	       : > "${cert_dir}${individual_certs[ -1]}.crt";
 	       for cert_line in "${cert_lines[@]}"; do
 	           echo "${cert_line}" >> "${cert_dir}${individual_certs[ -1]}.crt";
               done;
 	       cert_lines=( );
 	   elif [[ "${line}" =~ ^[[:space:]]*subject=.* ]]; then
	       individual_certs+=( "${BASH_REMATCH[0]//*CN = /}" );
 	       cert_lines+=( "${line}" );
 	   elif [[ "${line}" =~ ^[[:space:]]*$ ]]; then
               :;
 	   else
 	       cert_lines+=( "${line}" );
 	   fi;
 	done < "${pem_file}";
    done;
    for p7b_file in *.der.p7b; do
        der_file="${p7b_file//.p7b/}"
        { echo -e "\n[INFO] Converting ${p7b_file} to ${der_file}" && \
          openssl \
              pkcs7 \
              -in "${p7b_file}" \
              -inform DER \
              -print_certs \
              -out "${der_file}"; } || \
        { echo -e "\n[FAIL] Failed to convert ${p7b_file} to ${der_file}; exiting." 1>&2; \
          exit 1; };
	echo -e "\n[INFO] Splitting CA bundle file (${der_file}) into individual cert files and staging for inclusion in system CA trust." && \
 	while read -r line; do
 	   if [[ "${line}" =~ END.*CERTIFICATE ]]; then
 	       cert_lines+=( "${line}" );
	        : > "${cert_dir}${individual_certs[ -1]}.crt"
 	       for cert_line in "${cert_lines[@]}"; do
 	           echo "${cert_line}" >> "${cert_dir}${individual_certs[ -1]}.crt";
               done;
 	       cert_lines=( );
 	   elif [[ "${line}" =~ ^[[:space:]]*subject=.* ]]; then
	           individual_certs+=( "${BASH_REMATCH[0]//*CN = /}" );
 	           cert_lines+=( "${line}" );
 	   elif [[ "${line}" =~ ^[[:space:]]*$ ]]; then
               :;
 	   else
 	       cert_lines+=( "${line}" );
 	   fi;
 	done < "${der_file}";
    done && \
    { cd - &>/dev/null || exit 1; } && \
    echo -e "\n[INFO] Found a total of ${#individual_certs[@]} individual certs inside of CA bundles." && \
    # Placing all individual_certs into a key in uniq_cert array to deduplicate non-unique certs
    # This assumes that CN values for all certs are sufficiently unique keys to act as UIDs
    declare -A uniq_certs && \
    for individual_cert in "${individual_certs[@]}"; do
        uniq_certs["$individual_cert"]="${individual_cert}";
    done && \
    echo -e "\n[INFO] Found a total of ${#uniq_certs[@]} unique certs inside of CA bundles." && \
    { echo -e "\n[INFO] The following DoD certificate files are staged for inclusion in the system CA trust:" && \
      total_staged=0 && \
      for staged_file in "${cert_dir}"*; do
          echo "${staged_file}";
	  total_staged="$((total_staged+1))";
      done; } && \
      echo "===END OF LIST===" && \
    # This ensures the user is aware if any certificates appear to have been left out entirely by accident
    # While a check is still performed at the end that Desktop Anywhere is accessible, this ensures other sites are too
    { if [[ "${total_staged}" != "${#uniq_certs[@]}" ]]; then
          echo -e "\n[FAIL] Failed to stage all previously discovered unique certificates." 1>&2;
	  exit 1;
      fi; };
    { echo -e "\n[INFO] Adding staged DoD certificates (and any other previously staged certs) to system CA trust." && \
      update-ca-certificates --verbose --fresh && \
      echo -e "\n[INFO] Successfully added staged certificates to system CA trust."; } || \
    { echo -e "\n[FAIL] Failed to add staged certificates to system CA trust; exiting."; \
      exit 1;};
    { echo -e "\n[INFO] Verifying that Desktop Anywhere login gateway is accessible after certificate installation." && \
      wget -S --spider --timeout 10 https://afrcdesktops.us.af.mil && \
      echo -e "\n[INFO] Desktop Anywhere login gateway is accessible after certificate installation."; } || \
    { echo -e "\n[FAIL] Desktop Anywhere login gateway is not accessible after certificate installation; exiting." 2>&1;
      exit 1; };
    { rm -fr .certs/ || echo -e "[WARN] Failed to clean up temporary .certs directory."; };
fi;

# 2. Install VMWare Horizon

echo -e "\n[INFO] Checking if VMWare Horizon client is already installed.";
if hash vmware-view 2>/dev/null; then
    echo -e "\n[INFO] VMWare Horizon client is already installed; skipping installation.";
else
    echo -e "\n[INFO] VMWare Horizon client is not already installed; installing.";
    if ! test -f VMware-Horizon-Client-2006-8.0.0-16522670.x64.bundle; then
    	wget -O VMware-Horizon-Client-2006-8.0.0-16522670.x64.bundle https://download3.vmware.com/software/view/viewclients/CART21FQ2/VMware-Horizon-Client-2006-8.0.0-16522670.x64.bundle
    fi;
    chmod u+x VMware-Horizon-Client-2006-8.0.0-16522670.x64.bundle && \
    sudo TERM=dumb VMWARE_EULAS_AGREED=yes \
    ./VMware-Horizon-Client-2006-8.0.0-16522670.x64.bundle  --console --required \
    --set-setting vmware-horizon-smartcardsmartcardEnable yes \
    --set-setting vmware-horizon-rtavrtavEnable yes \
    --set-setting vmware-horizon-virtual-printing tpEnable yes \
    --set-setting vmware-horizon-tsdrtsdrEnable yes \
    --set-setting vmware-horizon-mmr mmrEnableyes \
    --set-setting vmware-horizon-media-provider mediaproviderEnable yes;
   if hash vmware-view 2>/dev/null; then
       echo -e "\n[INFO] Successfully installed VMware Horizon client.";
   else
       echo -e "\n[FAIL] Failed to install VMWare Horizon client." 1>&2;
       exit 1;
   fi;
fi;

# 3. Check for and install PKCS#11 libraries (e.g. OpenSC)

#Default locations
VMWARE_PCKS11_LOC="/usr/lib/vmware/view/pkcs11/"
OPENSC_LOC="/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

echo -e "\n[INFO] Testing if OpenSC is already installed.";
if test -f "OPENSC_LOC"; then
    echo -e "\n[INFO] OpenSC is already installed; skipping installation.";
else
    echo -e "\n[INFO] OpenSC is not already installed; installing.";
    sudo apt install -y opensc
    if test -f $OPENSC_LOC; then
        echo -e "\n[INFO] Successfully install OpenSC.";
    else
        echo -e "\n[FAIL] Failed to install OpenSC; exiting." 1>&2;
        exit 1;
    fi;
fi

echo -e "\n[INFO] Testing if VMWare has PCKS11 already installed.";
if test -d "$VMWARE_PCKS11_LOC"; then
    echo -e "\n[WARN] PKCS11 folder exists; Skipping; Check for previous installation.";
else
    echo -e "\n[INFO] Setting VMWare Horizon's PKCS11 library.";
    { sudo mkdir "$VMWARE_PCKS11_LOC" && \
      echo -e "\n[INFO] Symlinking OpenSC into default location ($VMWARE_PCKS11_LOC)." && \
      sudo ln -s "$OPENSC_LOC" "$VMWARE_PCKS11_LOC""libopenscpkcs11.so" && \
      sudo ls -hal "$VMWARE_PCKS11_LOC" && \
      echo -e "\n[INFO] Successfully set PCKS11 library.";
    } || \
    { echo -e "\n[FAIL] Failed to successfully set PCKS11 library; exiting."; \
      exit 1; }
fi

#4. Set preferences

if test -f "$HOME/.vmware/view-preferences"; then
    echo -e "\n[INFO] Preferences file already exists; skipping.";
else
echo -e "\n[INFO] Setting preferences for VMWare Horizon client configuration.";
{ sudo mkdir -p "$HOME/.vmware/" && \
  sudo chown -R "${SUDO_USER}":"${SUDO_USER}" "$HOME/.vmware/" && \
  echo "view.defaultBroker = 'afrcdesktops.us.af.mil'" >> "$HOME/.vmware/view-preferences" && \
  sudo chown -R "${SUDO_USER}":"${SUDO_USER}" "$HOME/.vmware/view-preferences" && \
  echo -e "\n[INFO] Successfully set VMWare Horizon configuration."; } || \
{ echo -e "\n[FAIL] Failed to set VMWare Horizon configuration; exiting."; \
  exit 1; };
fi

echo -e "\nInstallation complete! Launch Horizon and add the following server:";
echo -e "\nVDI Address: https://afrcdesktops.us.af.mil";
