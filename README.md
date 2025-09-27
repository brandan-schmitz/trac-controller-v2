# TRAC Panel Setup Instructions

Below are the steps necessary to install this application on the Raspberry Pi running the Bookworm version. Before proceeding, please make sure the `trac` user exists.

1. Install necessary dependencies for the main panel
   ```shell
   # Update the system package manager repository package list
   sudo apt update
   
   # Install necessary packages (Main panel only, remote panel use the command below)
   sudo apt install -y mosquitto mosquitto-clients python3 python3-pip python3-libgpiod python3-paho-mqtt clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev curl git unzip xz-utils zip libglu1-mesa mesa-utils
   
   # Install necessary packages (Remote panel only, main panel use the command above)
   sudo apt install -y mosquitto-clients clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev curl git unzip xz-utils zip libglu1-mesa mesa-utils
   ```

   

2. Enable Mosquitto and create the user in MQTT. You will be prompted to choose a password here. *(Main Panel Only)*
   ```shell
   # Enable mosquitto
   sudo systemctl enable --now mosquitto
   
   # Set the password for the tracpanel MQTT user
   sudo mosquitto_passwd -c /etc/mosquitto/passwd tracpanel
   ```

   

3. Clone the TRAC controller project from GitHub.

   ```bash
   # Move to the /opt directory where the application will be stored
   cd /opt
   
   # Clone the repository with Git
   sudo git clone https://github.com/brandan-schmitz/trac-controller-v2.git
   
   # Adjust the cloned project repository owner
   sudo chown trac:trac -R /opt/trac-controller-v2
   ```

   

4. Configure Mosquitto by copying the config file and adjusting its ownership and permissions *(Main Panel Only)*

   ```shell
   # Copy the file
   sudo cp /opt/trac-controller-v2/configs/trac.conf /etc/mosquitto/conf.d/trac.conf
   
   # Set ownership and permissions
   sudo chown root:root /etc/mosquitto/conf.d/trac.conf
   sudo chmod 0644 /etc/mosquitto/conf.d/trac.conf
   
   # Reload the MQTT service
   sudo systemctl restart mosquitto
   ```

   

5. Make sure that the `BROKER_PASS` variable in the `/opt/trac-controller-v2/scripts/gpio-controller.py` script is configured with the password set in step 2. *(Main Panel Only)*
   
6. Make sure the permissions on the script files are set correctly.

   ```shell
   # GPIO Controller (Main panel Only)
   sudo chmod +x /opt/trac-controller-v2/scripts/gpio-controller.py
   
   # trac-net-apply helper script (Both Panels)
   sudo chmod 0755 /opt/trac-controller-v2/scripts/trac-net-apply.sh
   sudo chmod +x /opt/trac-controller-v2/scripts/trac-net-apply.sh
   ```

   

7. Copy the  `trac-net-apply` sudoers file and update its ownership and permissions so that the `trac-net-apply.sh` script can be run without a password.
   ```shell
   # Copy the file
   sudo cp /opt/trac-controller-v2/configs/trac-net-helper /etc/sudoers.d/trac-net-helper
   
   # Apply ownership and permissions
   sudo chown root:root /etc/sudoers.d/trac-net-helper
   sudo chmod 0440 /etc/sudoers.d/trac-net-helper
   ```

   

8. Install Flutter and prepare it for use.
   ```shell
   # Navigate to the /opt directory where flutter will be installed
   cd /opt
   
   # Clone the flutter project
   sudo git clone https://github.com/flutter/flutter.git
   
   # Configure the ownsership on the flutter directory so that it can be used
   sudo chown -trac:trac /opt/flutter
   
   # Move into the flutter directory
   cd /opt/flutter
   
   # Checkout the specific version of flutter this project was built for
   git checkout tags/3.35.4
   
   # Export the flutter command to the path so it can be used
   echo 'export PATH=/opt/flutter/bin:$PATH' | sudo tee /etc/profile.d/flutter.sh
   
   # Source the flutter command script to avoid needing to logout and back in again
   source /etc/profile.d/flutter.sh
   
   # Run flutter doctor to prep the system
   flutter doctor
   ```

   

9. Build the flutter application.
   ```shell
   # Navigate back to the application directory
   cd /opt/trac-controller-v2
   
   # Get the dependencies flutter depends on for this project
   flutter pub get
   
   # Build the application
   flutter build linux --release
   ```

   

10. Copy the service files for the application and the gpio controller and appy proper ownership and permissions.
   ```shell
   # Copy the gpio-controller service file and apply its permissions (Main panel only)
   sudo cp /opt/trac-controller-v2/service-files/trac-gpio-controller.service /etc/systemd/system/trac-gpio-controller.service
   sudo chown root:root /etc/systemd/system/trac-gpio-controller.service
   sudo chmod 0755 /etc/systemd/system/trac-gpio-controller.service
   
   # Copy the trac-controller-ui service file and apply its permissions (Both panels)
   sudo cp /opt/trac-controller-v2/service-files/trac-controller-ui.service /etc/systemd/system/trac-controller-ui.service
   sudo chown root:root /etc/systemd/system/trac-controller-ui.service
   sudo chmod 0755 /etc/systemd/system/trac-controller-ui.service
   ```

   

11. Enable and start the services.
    ```shell
    # Reload the systemd daemon to pickup the new service files
    sudo systemctl daemon-reload
    
    # Start the gpio-controller (Main panel only)
    sudo systemctl enable --now trac-gpio-controller
    
    # Start the trac-controller-ui (Both panels)
    sudo systemctl enable --now trac-controller-ui
    ```

    