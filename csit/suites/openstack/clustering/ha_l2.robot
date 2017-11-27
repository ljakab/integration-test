*** Settings ***
Documentation     Test suite to verify packet flows between vm instances.
Suite Setup       Devstack Suite Setup    source_pwd=yes
Suite Teardown    Close All Connections
Test Setup        SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
Test Teardown     OpenStackOperations.Get Test Teardown Debugs
Library           SSHLibrary
Library           OperatingSystem
Library           RequestsLibrary
Library           Collections
Resource          ../../../libraries/Utils.robot
Resource          ../../../libraries/OpenStackOperations.robot
Resource          ../../../libraries/DevstackUtils.robot
Resource          ../../../libraries/OVSDB.robot
Resource          ../../../libraries/ClusterOvsdb.robot
Resource          ../../../libraries/ClusterManagement.robot
Resource          ../../../libraries/SetupUtils.robot
Variables         ../../../variables/Variables.py

*** Variables ***
${SECURITY_GROUP}    cl2_sg
@{NETWORKS_NAME}    cl2_net_1    cl2_net_2
@{SUBNETS_NAME}    cl2_sub_1    cl2_sub_2
@{NET_1_VM_INSTANCES}    cl2_net_1_vm_1    cl2_net_1_vm_2    cl2_net_1_vm_3
@{NET_2_VM_INSTANCES}    cl2_net_2_vm_1    cl2_net_2_vm_2    cl2_net_2_vm_3
@{SUBNETS_RANGE}    26.0.0.0/24    27.0.0.0/24
@{VM_IPS_NOT_DELETED}    26.0.0.4
@{CLUSTER_DOWN_LIST}    ${1}    ${2}

*** Test Cases ***
Create All Controller Sessions
    [Documentation]    Create sessions for all three contorllers.
    ClusterManagement.ClusterManagement Setup

Create Network net_1
    [Documentation]    Create Network with neutron request.
    OpenStackOperations.Create Network    @{NETWORKS_NAME}[0]

Create Subnet For net_1
    [Documentation]    Create Sub Net for the Network with neutron request.
    OpenStackOperations.Create SubNet    @{NETWORKS_NAME}[0]    @{SUBNETS_NAME}[0]    @{SUBNETS_RANGE}[0]

Create Network net_2
    [Documentation]    Create Network with neutron request.
    OpenStackOperations.Create Network    @{NETWORKS_NAME}[1]

Create Subnet For net_2
    [Documentation]    Create Sub Net for the Network with neutron request.
    OpenStackOperations.Create SubNet    @{NETWORKS_NAME}[1]    @{SUBNETS_NAME}[1]    @{SUBNETS_RANGE}[1]

Add Ssh Allow All Rule
    [Documentation]    Allow all TCP/UDP/ICMP packets for this suite
    OpenStackOperations.Create Allow All SecurityGroup    ${SECURITY_GROUP}

Create Bridge Manually and Verify Before Fail
    [Documentation]    Create bridge with OVS command and verify it gets applied from all instances.
    ClusterOvsdb.Create Sample Bridge Manually And Verify    ${OS_CONTROL_NODE_IP}

Add Tap Device Manually and Verify Before Fail
    [Documentation]    Add tap devices to the bridge with OVS command and verify it gets applied from all instances.
    ClusterOvsdb.Add Sample Tap Device To The Manual Bridge And Verify    ${OS_CONTROL_NODE_IP}

Delete the Bridge Manually and Verify Before Fail
    [Documentation]    Delete bridge with OVS command and verify it gets deleted from all instances.
    ClusterOvsdb.Delete Sample Bridge Manually And Verify    ${OS_CONTROL_NODE_IP}

Take Down ODL1
    [Documentation]    Kill the karaf in First Controller
    ${new_cluster_list} =    ClusterManagement.Kill Single Member    1
    BuiltIn.Set Suite Variable    ${new_cluster_list}

Create Bridge Manually and Verify After Fail
    [Documentation]    Create bridge with OVS command and verify it gets applied from all instances.
    ClusterOvsdb.Create Sample Bridge Manually And Verify    ${OS_CONTROL_NODE_IP}    ${new_cluster_list}

Add Tap Device Manually and Verify After Fail
    [Documentation]    Add tap devices to the bridge with OVS command and verify it gets applied from all instances.
    ClusterOvsdb.Add Sample Tap Device To The Manual Bridge And Verify    ${OS_CONTROL_NODE_IP}    ${new_cluster_list}

Delete the Bridge Manually and Verify After Fail
    [Documentation]    Delete bridge with OVS command and verify it gets deleted from all instances.
    ClusterOvsdb.Delete Sample Bridge Manually And Verify    ${OS_CONTROL_NODE_IP}    ${new_cluster_list}

Bring Up ODL1
    [Documentation]    Bring up ODL1 again
    ClusterManagement.Start Single Member    1

Create Bridge Manually and Verify After Recover
    [Documentation]    Create bridge with OVS command and verify it gets applied from all instances.
    ClusterOvsdb.Create Sample Bridge Manually And Verify    ${OS_CONTROL_NODE_IP}

Add Tap Device Manually and Verify After Recover
    [Documentation]    Add tap devices to the bridge with OVS command and verify it gets applied from all instances.
    ClusterOvsdb.Add Sample Tap Device To The Manual Bridge And Verify    ${OS_CONTROL_NODE_IP}

Delete the Bridge Manually and Verify After Recover
    [Documentation]    Delete bridge with OVS command and verify it gets deleted from all instances.
    ClusterOvsdb.Delete Sample Bridge Manually And Verify    ${OS_CONTROL_NODE_IP}

Take Down ODL2
    [Documentation]    Kill the karaf in Second Controller
    ClusterManagement.Kill Single Member    2

Create Vm Instances For net_1
    [Documentation]    Create Vm instances using flavor and image names for a network.
    BuiltIn.Log    ${devstack_conn_id}
    OpenStackOperations.Create Vm Instances    @{NETWORKS_NAME}[0]    ${NET_1_VM_INSTANCES}    sg=${SECURITY_GROUP}

Create Vm Instances For net_2
    [Documentation]    Create Vm instances using flavor and image names for a network.
    OpenStackOperations.Create Vm Instances    @{NETWORKS_NAME}[1]    ${NET_2_VM_INSTANCES}    sg=${SECURITY_GROUP}

Check Vm Instances Have Ip Address
    @{NET_1_VM_IPS}    ${NET_1_DHCP_IP} =    OpenStackOperations.Get VM IPs    @{NET_1_VM_INSTANCES}
    @{NET_2_VM_IPS}    ${NET_2_DHCP_IP} =    OpenStackOperations.Get VM IPs    @{NET_2_VM_INSTANCES}
    BuiltIn.Set Suite Variable    @{NET_1_VM_IPS}
    BuiltIn.Set Suite Variable    @{NET_2_VM_IPS}
    BuiltIn.Should Not Contain    ${NET_1_VM_IPS}    None
    BuiltIn.Should Not Contain    ${NET_2_VM_IPS}    None
    BuiltIn.Should Not Contain    ${NET_1_DHCP_IP}    None
    BuiltIn.Should Not Contain    ${NET_2_DHCP_IP}    None
    [Teardown]    BuiltIn.Run Keywords    OpenStackOperations.Show Debugs    @{NET_1_VM_INSTANCES}    @{NET_2_VM_INSTANCES}
    ...    AND    OpenStackOperations.Get Test Teardown Debugs

Bring Up ODL2
    [Documentation]    Bring up ODL2 again
    ClusterManagement.Start Single Member    2

Ping Vm Instance1 In net_1
    [Documentation]    Check reachability of vm instances by pinging to them.
    OpenStackOperations.Ping Vm From DHCP Namespace    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[0]

Ping Vm Instance2 In net_1
    [Documentation]    Check reachability of vm instances by pinging to them.
    OpenStackOperations.Ping Vm From DHCP Namespace    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[1]

Ping Vm Instance3 In net_1
    [Documentation]    Check reachability of vm instances by pinging to them.
    OpenStackOperations.Ping Vm From DHCP Namespace    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[2]

Ping Vm Instance1 In net_2
    [Documentation]    Check reachability of vm instances by pinging to them.
    OpenStackOperations.Ping Vm From DHCP Namespace    @{NETWORKS_NAME}[1]    @{NET_2_VM_IPS}[0]

Ping Vm Instance2 In net_2
    [Documentation]    Check reachability of vm instances by pinging to them.
    OpenStackOperations.Ping Vm From DHCP Namespace    @{NETWORKS_NAME}[1]    @{NET_2_VM_IPS}[1]

Ping Vm Instance3 In net_2
    [Documentation]    Check reachability of vm instances by pinging to them.
    OpenStackOperations.Ping Vm From DHCP Namespace    @{NETWORKS_NAME}[1]    @{NET_2_VM_IPS}[2]

Take Down ODL3
    [Documentation]    Kill the karaf in Third Controller
    ClusterManagement.Kill Single Member    3

Connectivity Tests From Vm Instance1 In net_1
    [Documentation]    Logging to the vm instance using generated key pair.
    OpenStackOperations.Test Operations From Vm Instance    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[0]    ${NET_1_VM_IPS}

Connectivity Tests From Vm Instance2 In net_1
    [Documentation]    Logging to the vm instance using generated key pair.
    OpenStackOperations.Test Operations From Vm Instance    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[1]    ${NET_1_VM_IPS}

Connectivity Tests From Vm Instance3 In net_1
    [Documentation]    Logging to the vm instance using generated key pair.
    OpenStackOperations.Test Operations From Vm Instance    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[2]    ${NET_1_VM_IPS}

Bring Up ODL3
    [Documentation]    Bring up ODL3 again
    ClusterManagement.Start Single Member    3

Take Down ODL1 and ODL2
    [Documentation]    Kill the karaf in First and Second Controller
    ClusterManagement.Kill Members From List Or All    ${CLUSTER_DOWN_LIST}

Connectivity Tests From Vm Instance1 In net_2
    [Documentation]    Logging to the vm instance using generated key pair.
    OpenStackOperations.Test Operations From Vm Instance    @{NETWORKS_NAME}[1]    @{NET_2_VM_IPS}[0]    ${NET_2_VM_IPS}

Connectivity Tests From Vm Instance2 In net_2
    [Documentation]    Logging to the vm instance using generated key pair.
    OpenStackOperations.Test Operations From Vm Instance    @{NETWORKS_NAME}[1]    @{NET_2_VM_IPS}[1]    ${NET_2_VM_IPS}

Connectivity Tests From Vm Instance3 In net_2
    [Documentation]    Logging to the vm instance using generated key pair.
    OpenStackOperations.Test Operations From Vm Instance    @{NETWORKS_NAME}[1]    @{NET_2_VM_IPS}[2]    ${NET_2_VM_IPS}

Bring Up ODL1 and ODL2
    [Documentation]    Bring up ODL1 and ODL2 again.
    ClusterManagement.Start Members From List Or All    ${CLUSTER_DOWN_LIST}

Delete Vm Instance
    [Documentation]    Delete Vm instances using instance names.
    OpenStackOperations.Delete Vm Instance    @{NET_1_VM_INSTANCES}[0]

No Ping For Deleted Vm
    [Documentation]    Check non reachability of deleted vm instances by pinging to them.
    ${output} =    OpenStackOperations.Ping From DHCP Should Not Succeed    @{NETWORKS_NAME}[0]    @{NET_1_VM_IPS}[0]

Delete Vm Instances In net_1
    [Documentation]    Delete Vm instances using instance names in network_1.
    : FOR    ${vm}    IN    @{NET_1_VM_INSTANCES}
    \    OpenStackOperations.Delete Vm Instance    ${vm}

Delete Vm Instances In net_2
    [Documentation]    Delete Vm instances using instance names in network_2.
    : FOR    ${vm}    IN    @{NET_2_VM_INSTANCES}
    \    OpenStackOperations.Delete Vm Instance    ${vm}

Delete Sub Networks In net_1
    [Documentation]    Delete Sub Nets for the Networks with neutron request.
    OpenStackOperations.Delete SubNet    @{SUBNETS_NAME}[0]

Delete Sub Networks In net_2
    [Documentation]    Delete Sub Nets for the Networks with neutron request.
    OpenStackOperations.Delete SubNet    @{SUBNETS_NAME}[1]

Delete Networks
    [Documentation]    Delete Networks with neutron request.
    : FOR    ${network}    IN    @{NETWORKS_NAME}
    \    OpenStackOperations.Delete Network    ${network}

Delete Security Group
    [Documentation]    Delete security groups with neutron request
    OpenStackOperations.Delete SecurityGroup    ${SECURITY_GROUP}

Verify Flows Cleanup
    [Documentation]    Verify that flows have been cleaned up properly after removing all neutron configurations
    DataModels.Verify Flows Are Cleaned Up On All OpenStack Nodes