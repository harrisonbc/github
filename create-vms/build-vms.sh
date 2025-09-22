# This script will create a number of VM's on a KVM/Libvirt Host using the Image and settings in variables.env
# pass the command "create" to create the resources
# pass the command "destroy" to delete the resources


## Work in Progress
# 
####################################################
# Script to build image to be used to bootstrap Required VMs 
####################################################

####################################################
# Retrieve parameters 
############################################################################################

set -a
source variables.env


# Download Seed Image once it is created 
# 
# wget https://rancher.harrison.local/elemental/seedimage/xjdj84sgggjxd9hdw6kh45lhsdktmhxw4tkzf6p89xjlhnk2kctpqt/fire-nodes-2025-09-22T13:27:38Z.iso
kubectl wait --for=condition=ready pod -n fleet-default fire-img
kubectl wait --for=condition=ready pod -n fleet-default fire-img

if [ ! -f $LOCATION/$DISKIMAGE ]; then 

    wget --no-check-certificate `kubectl get seedimage -n fleet-default fire-img -o jsonpath="{.status.downloadURL}"` -O $LOCATION/$DISKIMAGE

fi

####################################################
# Create VMs
####################################################

for VM in $IPS; do

# Create VM Hostname & associated NIC mac address

  I=$(printf "%02d" $N) # Make 2 digits
  A=$VMNAME$I.$DOMAIN
  macaddr=$(echo $A|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')


  if [[ $1 == "create" ]]; then

    echo "Create VM $A with MAC Address: $macaddr"

    # Create User Data File
    # echo "envsubst < cloud-init.yaml.tmpl > $LOCATION/cloud-init-$VMNAME$I.yaml"
#    echo "Create $LOCATION/cloud-init-$VMNAME$I.yaml"
#    envsubst < templates/cloud-init.yaml.tmpl > $LOCATION/cloud-init-$VMNAME$I.yaml

    # Create Network Config File
    # echo "envsubst < network-config.yaml.tmpl > $LOCATION/network-config-$VMNAME$I.yaml"
#    echo "Create $LOCATION/network-config-$VMNAME$I.yaml"
#    envsubst < templates/network-config.yaml.tmpl > $LOCATION/network-config-$VMNAME$I.yaml

    # Create DNS A Records in DNS server
    echo "Create DNS Record $A A $VM"

    URL="http://$API_HOST/api/zones/records/add?token=$TOKEN&domain=$A&type=A&overwrite=true&ipAddress=$VM&ptr=true"
    # echo $URL
    RESULT=$(curl -s $URL)
    # echo $RESULT

    # Now create VM
    virt-install \
        --virt-type kvm  \
        --name $VMNAME$I \
        --boot uefi \
        --memory $MEMORY \
        --vcpus $VCPUS \
        --disk=size=$DISK,backing_store=$LOCATION/$DISKIMAGE,bus=virtio,format=qcow2 \
        --install no_install=yes \
        --network=$NETWORK,mac=$macaddr \
        --graphics vnc,listen=0.0.0.0,keymap=local \
        --osinfo detect=on,name=sle-unknown \
        --noautoconsole

    echo
    echo
      
  fi

  if [[ $1 == "destroy" ]]; then

#    echo "Unregister $A from scc.suse.com with SUSEconnect"
#    ssh brynn@$A sudo transactional-update register -d 

    echo "Destroy VM $A with MAC Address: $macaddr"

    virsh destroy $VMNAME$I
    virsh undefine $VMNAME$I --nvram
    virsh vol-delete  $VMNAME$I.qcow2 default
    URL="http://$API_HOST/api/zones/records/delete?token=$TOKEN&domain=$A&type=A&value=$VM"
    RESULT=$(curl -s $URL)

    echo

  fi

  # Increment postfix
  ((N++))
done


if [[ $1 == "" ]]; then

  echo "No option provided"
  echo "Please supply 'create' or 'destroy' parameter to create/remove VMs"
#  echo

fi


set +a



# virsh destroy VMName - to stop a VM
# virsh undefine VMName - to delete a VM
# virsh vol-delete VOLNAME POOL - to delete a volume VOLNAME From POOL
# if [ "$1" == "delete" ]; then echo "Deleted" 
# fi
# 
