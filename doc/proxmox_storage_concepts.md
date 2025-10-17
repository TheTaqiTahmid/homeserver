# Proxmox LVM Architecture and Concepts

## 1. Overview of LVM

Logical Volume Manager (LVM) provides a flexible storage management layer
between physical disks and file systems. It allows administrators to allocate,
resize, and manage storage dynamically, without the limitations of fixed disk
partitions.

The storage hierarchy under LVM is as follows:

Physical Volume (PV) → Volume Group (VG) → Logical Volume (LV)

Each layer abstracts the one beneath it to provide logical storage that can be
managed independently of the physical disk structure.

## 2. Core LVM Components

a. Physical Volume (PV)

A Physical Volume represents a raw storage device (such as a disk or a
partition) that LVM can manage.

It is initialized for use with the command:

pvcreate /dev/sda2

This prepares the partition /dev/sda2 as LVM-capable storage.

b. Volume Group (VG)

A Volume Group is a pool of storage composed of one or more Physical Volumes.
It aggregates multiple disks or partitions into a single logical storage space.
Example:

vgcreate pve /dev/sda2

In Proxmox, the default Volume Group created during installation is typically
named pve. Once created, Logical Volumes can be allocated from this group.

c. Logical Volume (LV)

A Logical Volume functions like a virtual partition carved from a Volume Group.
It behaves like a standard block device and can be formatted, mounted, or used
for virtual machine disks.

Example:

lvcreate -L 50G -n vm-100-disk pve

This command creates a 50 GB logical volume named vm-100-disk within the pve
Volume Group.

In Proxmox, each virtual machine disk backed by LVM appears as an LV under
/dev/<VG>/, for example:

/dev/pve/vm-100-disk-0

d. Thin Pool and Thin Volumes

A thin pool enables thin provisioning, which allows Logical Volumes to allocate
physical space on demand rather than all at once.

A thin pool is created as a special Logical Volume:

lvcreate -L 500G -T pve/data

Once the pool exists, thin-provisioned LVs can be created within it:

lvcreate -V 100G -T pve/data -n vm-101-disk

Here, vm-101-disk has a logical size of 100 GB but consumes physical space only
as data is written. This is the mechanism used by Proxmox’s “LVM-Thin” storage
type.

## 3. Example: Creating an Extra LV for /var/lib/vz

To create a new thin-provisioned LV for /var/lib/vz, the following command is used:

lvcreate -n vz -V 10G pve/data

Explanation:

-n vz: Names the new LV “vz”.

-V 10G: Defines a virtual (thin-provisioned) size of 10 GB.

pve/data: Specifies that the LV should be created within the thin pool data
inside the VG pve.

This creates /dev/pve/vz, a 10 GB thin-provisioned LV that can then be formatted
and mounted:

mkfs.ext4 /dev/pve/vz
mkdir /var/lib/vz
mount /dev/pve/vz /var/lib/vz

This approach isolates /var/lib/vz—commonly used by Proxmox to store container
data, ISO images, and templates—from the root filesystem.

4. Typical Proxmox LVM Layout

A standard Proxmox installation configured with LVM uses a single Volume Group
(pve) containing several Logical Volumes:

/dev/sda (disk)
└── /dev/sda2 (partition)
└── PV → VG: pve
├── LV: root → Mounted as /
├── LV: swap → Used as swap space
└── LV-Thin: data → Thin pool for VM and container disks
├── Thin LV: vm-100-disk-0
└── Thin LV: vm-101-disk-0

This structure allows the operating system, swap, and virtual machine disks to
share a single pool of storage while maintaining isolation through logical
volumes.

## 4. Example of Creating a new LVM thin pool and LV

To create a new LVM thin pool and a thin-provisioned logical volume,
follow these steps:

1. **Create a Physical Volume (if not already done)**

   If you have a new disk or partition to use, initialize it as a Physical Volume:

   ```bash
   pvcreate /dev/sdb1
   ```

2. **Create a Volume Group**
   Create a new Volume Group that includes the Physical Volume:

   ```bash
   vgcreate backup /dev/sdb1
   ```

3. **Create a Thin Pool**
   Create a thin pool within the Volume Group:
   ```bash
   lvcreate -L 200G -T backup/thinpool
   ```
4. Configure the thin pool to storage.cfg
   ```
   lvmthin: backup-lvm
       thinpool backup/thinpool
       vgname backup
       content rootdir,images
       nodes proxmox-node1,proxmox-node2 # List of cluster nodes
   ```
