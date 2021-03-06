*** Settings ***
Documentation     Test suite connecting ODL to Mininet
Suite Setup       BuiltIn.Run Keywords    SetupUtils.Setup_Utils_For_Setup_And_Teardown
...               AND    Create Session    session    http://${ODL_SYSTEM_IP}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS}
Suite Teardown    Delete All Sessions
Test Setup        SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
Test Teardown     Collect OVSDB Debugs
Library           SSHLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           RequestsLibrary
Library           ../../../libraries/Common.py
Variables         ../../../variables/Variables.py
Resource          ../../../libraries/SetupUtils.robot
Resource          ../../../libraries/Utils.robot
Resource          ../../../libraries/OVSDB.robot

*** Variables ***
${OVSDB_PORT}     6640
${OF_PORT}        6653
${FLOWS_TABLE_20}    actions=goto_table:20
${FLOW_CONTROLLER}    actions=CONTROLLER:65535
${FLOWS_TABLE_30}    actions=goto_table:30
${FLOWS_TABLE_31}    actions=goto_table:31
${FLOWS_TABLE_40}    actions=resubmit(,39),resubmit(,40)
${FLOWS_TABLE_50}    actions=goto_table:50
${FLOWS_TABLE_60}    actions=goto_table:60
${FLOWS_TABLE_70}    actions=goto_table:70
${FLOWS_TABLE_80}    actions=goto_table:80
${FLOWS_TABLE_90}    actions=goto_table:90
${FLOWS_TABLE_100}    actions=goto_table:100
${FLOWS_TABLE_105}    actions=goto_table:105
${FLOWS_TABLE_110}    actions=goto_table:110
${FLOW_DROP}      actions=drop
${PING_NOT_CONTAIN}    Destination Host Unreachable
@{node_list}      ovsdb://uuid/

*** Test Cases ***
Make the OVS instance to listen for connection
    [Documentation]    Connect OVS to ODL
    [Tags]    OVSDB netvirt
    Clean Up Ovs    ${TOOLS_SYSTEM_IP}
    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl set-manager tcp:${ODL_SYSTEM_IP}:${OVSDB_PORT}
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl show
    ${pingresult}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    ping ${ODL_SYSTEM_IP} -c 4
    Should Not Contain    ${pingresult}    ${PING_NOT_CONTAIN}
    Wait Until Keyword Succeeds    8s    2s    Check For Elements At URI    ${OPERATIONAL_TOPO_API}    ${node_list}

Get manager connection
    [Documentation]    This will verify if the OVS manager is connected
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl show
    ${lines}=    Get Lines Containing String    ${output}    is_connected
    ${manager}=    Get Line    ${lines}    0
    Should Contain    ${manager}    true

Get controller connection
    [Documentation]    This will verify if the OpenFlow controller is connected on all bridges
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl show
    ${lines}=    Get Lines Containing String    ${output}    is_connected
    ${list}=    Split String    ${lines}    \n
    Remove From List    ${list}    0
    : FOR    ${controller}    IN    @{list}
    \    Should Contain    ${controller}    true

Get bridge setup
    [Documentation]    This request is verifying that the br-int bridge has been created
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl show
    Should Contain    ${output}    Controller "tcp:${ODL_SYSTEM_IP}:${OF_PORT}"
    Should Contain    ${output}    Bridge br-int

Get port setup
    [Documentation]    This will check the port br-int has been created
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl show
    Should Contain    ${output}    Port br-int

Get interface setup
    [Documentation]    This verify the interface br-int has been created
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-vsctl show
    Should Contain    ${output}    Interface br-int

Get the bridge flows
    [Documentation]    This request fetch the OF13 flow tables to verify the flows are correctly added
    [Tags]    OVSDB netvirt
    ${output}    Run Command On Remote System    ${TOOLS_SYSTEM_IP}    sudo ovs-ofctl -O Openflow13 dump-flows br-int
    Should Contain    ${output}    ${FLOWS_TABLE_20}
    Should Contain    ${output}    ${FLOW_CONTROLLER}
    Should Contain    ${output}    ${FLOWS_TABLE_30}
    Should Contain    ${output}    ${FLOWS_TABLE_31}
    Should Contain    ${output}    ${FLOWS_TABLE_40}
    Should Contain    ${output}    ${FLOWS_TABLE_50}
    Should Contain    ${output}    ${FLOWS_TABLE_60}
    Should Contain    ${output}    ${FLOWS_TABLE_70}
    Should Contain    ${output}    ${FLOWS_TABLE_80}
    Should Contain    ${output}    ${FLOWS_TABLE_90}
    Should Contain    ${output}    ${FLOWS_TABLE_100}
    Should Contain    ${output}    ${FLOWS_TABLE_105}
    Should Contain    ${output}    ${FLOWS_TABLE_110}
    Should Contain    ${output}    ${FLOW_DROP}
