# raspinit

This project generates Raspberry Pi images that are pre-baked with specific files. The primary intention is to support **cloud-init**-based auto-configuration.

## Prerequisites

  * Docker needs to be installed, as it's used to define a portable build context.
  * `make` needs to be installed

## Getting started

1. **Pull down the repository to your local machine**

    ```
    git clone https://github.com/codingwithkansas/raspinit.git
    ```


2. **Update config.json with appropriate values**

    | Attribute       | Description | Required    |
    | --------------- | ----------- | ----------- |
    | output_filename | Name of generated file. Example: `"raspicustom123"` will generate the output image at `dist/raspicustom123.img` | Yes |
    | base_image_url  | The URL of the `.img` or `.img.xz` source image to modify | Required if `base_image` is empty |
    | base_image      | The path of a local `.img` or `.img.xz` source image to modify | Required if `base_image_url` is empty |



3. **Update the `templates` directory as needed.** 
    
    All files within the `templates/boot-partition` directory will be copied to the boot partition.

    All files within the `templates/root-partition` directory will be copied to the root directory of the data partition. 

    This functionality enables __cloud-init__ OS auto-configuration to be invoked, by configuring the expected files at `templates/boot-partition/user-data` and `templates/boot-partition/network-config`.

    **Example: Create a user-data file for cloud-init**
    ```
    $ cat <<EOF > templates/boot-partition/user-data
      #cloud-config
      package_update: true
      package_upgrade: true
      write_files:
      - path: /var/test.txt
        content: |
          [INTENTIONALLY LEFT BLANK]
      runcmd: []
      bootcmd: []
      EOF
    ```
    
    **Example: Create a network-config file for cloud-init**
    ```
    $ cat <<EOF > templates/boot-partition/user-data
      network:
        version: 2
        ethernets:
          eth0:
            dhcp4: false
            addresses: [192.168.1.10/24]
            gateway4: 192.168.1.1
            nameservers:
              addresses: [1.1.1.1]
      EOF
    ```


4. **Build the pre-baked image file**

    The generated image will be located in the build output directory: `dist/`

    ```
    $ make build
    ...
    $ ls dist/
      <output_filename>.img
    ```

## Bugs

  * Unable to add large files to generated image "No space left on device" due to hacky method of mounting partitions.
