*** Settings ***
Library           SSHLibrary
Library           String
Library           DateTime
Library           Collections
Library           json
Library           RequestsLibrary
Variables         ../variables/Variables.py
Resource          ./Utils.robot

*** Variables ***
${vlan_topo_10}    sudo mn --controller=remote,ip=${CONTROLLER} --custom vlan_vtn_test.py --topo vlantopo
${vlan_topo_13}    sudo mn --controller=remote,ip=${CONTROLLER} --custom vlan_vtn_test.py --topo vlantopo --switch ovsk,protocols=OpenFlow13
${VERSION_VTN}    controller/nb/v2/vtn/version
${VTN_INVENTORY}    restconf/operational/vtn-inventory:vtn-nodes
${DUMPFLOWS_OF10}    dpctl dump-flows -O OpenFlow10
${DUMPFLOWS_OF13}    dpctl dump-flows -O OpenFlow13
${index}          7
@{FLOWELMENTS}    nw_src=10.0.0.1    nw_dst=10.0.0.3    actions=drop
@{BRIDGE1_DATAFLOW}    "reason":"PORTMAPPED"    "virtual-node-path":{"bridge-name":"vBridge1","tenant-name":"Tenant1","interface-name":"if2"}
@{BRIDGE2_DATAFLOW}    "reason":"PORTMAPPED"    "virtual-node-path":{"bridge-name":"vBridge2","tenant-name":"Tenant1","interface-name":"if3"}
${vlanmap_bridge1}    200
${vlanmap_bridge2}    300
@{VLANMAP_BRIDGE1_DATAFLOW}    "reason":"VLANMAPPED"    "virtual-node-path":{"bridge-name":"vBridge1_vlan","tenant-name":"Tenant1","vlan-map-id":"ANY.200"}
@{VLANMAP_BRIDGE2_DATAFLOW}    "reason":"VLANMAPPED"    "virtual-node-path":{"bridge-name":"vBridge2_vlan","tenant-name":"Tenant1","vlan-map-id":"ANY.300"}
${out_before_pathpolicy}    output:2
${out_after_pathpolicy}    output:3
${pathpolicy_topo_13}    sudo mn --controller=remote,ip=${CONTROLLER} --custom topo-3sw-2host_multipath.py --topo pathpolicytopo --switch ovsk,protocols=OpenFlow13
${pathpolicy_topo_10}    sudo mn --controller=remote,ip=${CONTROLLER} --custom topo-3sw-2host_multipath.py --topo pathpolicytopo --switch ovsk,protocols=OpenFlow10
@{PATHMAP_ATTR}    "index":"1"    "condition":"flowcond_path"    "policy":"1"
${policy_id}      1
${in_port}        1
@{PATHPOLICY_ATTR}    "id":1    "port-desc":"openflow:4,2,s4-eth2"
${custom}         ${CURDIR}/${CREATE_PATHPOLICY_TOPOLOGY_FILE_PATH}

*** Keywords ***
Start SuiteVtnMa
    [Documentation]    Start VTN Manager Rest Config Api Test Suite
    Create Session    session    http://${CONTROLLER}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS}
    BuiltIn.Wait_Until_Keyword_Succeeds    30    3    Fetch vtn list
    Start Suite

Start SuiteVtnMaTest
    [Documentation]    Start VTN Manager Test Suite
    Create Session    session    http://${CONTROLLER}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS}

Stop SuiteVtnMa
    [Documentation]    Stop VTN Manager Test Suite
    Delete All Sessions
    Stop Suite

Stop SuiteVtnMaTest
    [Documentation]    Stop VTN Manager Test Suite
    Delete All Sessions

Fetch vtn list
    [Documentation]    Check if VTN Manager is up.
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn:vtns
    Should Be Equal As Strings    ${resp.status_code}    200

Fetch vtn switch inventory
    [Arguments]    ${sw_name}
    [Documentation]    Check if Switch is detected.
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-inventory:vtn-nodes/vtn-node/${sw_name}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a Vtn
    [Arguments]    ${vtn_name}
    [Documentation]    Create a vtn with specified parameters.
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn:update-vtn    data={"input": {"tenant-name":${vtn_name}, "update-mode": "CREATE","operation": "SET", "description": "creating vtn", "idle-timeout":300, "hard-timeout":0}}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a vBridge
    [Arguments]    ${vtn_name}    ${vbr_name}
    [Documentation]    Create a vBridge in a VTN
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-vbridge:update-vbridge    data={"input": {"update-mode": "CREATE","operation":"SET", "tenant-name":${vtn_name}, "bridge-name":${vbr_name}, "description": "vbrdige created"}}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a interface
    [Arguments]    ${vtn_name}    ${vbr_name}    ${interface_name}
    [Documentation]    Create a interface into a vBridge of a VTN
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-vinterface:update-vinterface    data={"input": {"update-mode":"CREATE","operation":"SET", "tenant-name":${vtn_name}, "bridge-name":${vbr_name}, "description": "vbrdige interfacecreated", "enabled":"true", "interface-name": ${interface_name}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a portmap
    [Arguments]    ${vtn_name}    ${vbr_name}    ${interface_name}    ${node_id}    ${port_id}
    [Documentation]    Create a portmap for a interface of a vbridge
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-port-map:set-port-map    data={"input": { "tenant-name":${vtn_name}, "bridge-name":${vbr_name}, "interface-name": ${interface_name}, "node":"${node_id}", "port-name":"${port_id}"}}
    Should Be Equal As Strings    ${resp.status_code}    200

Delete a Vtn
    [Arguments]    ${vtn_name}
    [Documentation]    Delete a vtn with specified parameters.
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn:remove-vtn    data={"input": {"tenant-name":${vtn_name}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a vlanmap
    [Arguments]    ${vtn_name}    ${vbr_name}    ${vlan_id}
    [Documentation]    Create a vlanmap
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-vlan-map:add-vlan-map    data={"input": {"tenant-name":${vtn_name},"bridge-name":${vbr_name},"vlan-id":${vlan_id}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Verify Data Flows
    [Arguments]    ${vtn_name}    ${vBridge_name}
    [Documentation]    Verify the reason and physical data flows for the specified vtn and vbridge
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-flow-impl:vtn-flows/vtn-flow-table/${vtn_name}
    Run Keyword If    '${vBridge_name}' == 'vBridge1'    DataFlowsForBridge    ${resp}    @{BRIDGE1_DATAFLOW}
    ...    ELSE IF    '${vBridge_name}' == 'vBridge2'    DataFlowsForBridge    ${resp}    @{BRIDGE2_DATAFLOW}
    ...    ELSE IF    '${vBridge_name}' == 'vBridge1_vlan'    DataFlowsForBridge    ${resp}    @{VLANMAP_BRIDGE1_DATAFLOW}
    ...    ELSE    DataFlowsForBridge    ${resp}    @{VLANMAP_BRIDGE2_DATAFLOW}

Start PathSuiteVtnMaTest
    [Documentation]    Start VTN Manager Test Suite and Mininet
    Start SuiteVtnMaTest
    Start Mininet    ${MININET}    ${pathpolicy_topo_13}    ${custom}

Start PathSuiteVtnMaTestOF10
    [Documentation]    Start VTN Manager Test Suite and Mininet in Open Flow 10 Specification
    Start SuiteVtnMaTest
    Start Mininet    ${MININET}    ${pathpolicy_topo_10}    ${custom}

Stop PathSuiteVtnMaTest
    [Documentation]    Cleanup/Shutdown work at the completion of all tests.
    Delete All Sessions
    Stop Mininet    ${mininet_conn_id}

DataFlowsForBridge
    [Arguments]    ${resp}    @{BRIDGE_DATAFLOW}
    [Documentation]    Verify whether the required attributes exists.
    : FOR    ${dataflowElement}    IN    @{BRIDGE_DATAFLOW}
    \    should Contain    ${resp.content}    ${dataflowElement}

Add a pathmap
    [Arguments]    ${pathmap_data}
    [Documentation]    Create a pathmap for a vtn
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-path-map:set-path-map    data=${pathmap_data}
    Should Be Equal As Strings    ${resp.status_code}    200

Get a pathmap
    [Documentation]    Get a pathmap for a vtn.
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-path-map:global-path-maps
    : FOR    ${pathElement}    IN    @{PATHMAP_ATTR}
    \    should Contain    ${resp.content}    ${pathElement}

Add a pathpolicy
    [Arguments]    ${pathpolicy_data}
    [Documentation]    Create a pathpolicy for a vtn
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-path-policy:set-path-policy    data=${pathpolicy_data}
    Should Be Equal As Strings    ${resp.status_code}    200

Get a pathpolicy
    [Arguments]    ${pathpolicy_id}
    [Documentation]    Get a pathpolicy for a vtn.
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-path-policy:vtn-path-policies/vtn-path-policy/${pathpolicy_id}
    : FOR    ${pathpolicyElement}    IN    @{PATHPOLICY_ATTR}
    \    should Contain    ${resp.content}    ${pathpolicyElement}

Delete a pathmap
    [Arguments]    ${tenant_path}
    [Documentation]    Remove a pathmap for a vtn
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-path-map:remove-path-map    data={"input":{"tenant-name":"${tenant_path}","map-index":["${policy_id}"]}}
    Should Be Equal As Strings    ${resp.status_code}    200

Delete a pathpolicy
    [Arguments]   ${policy_id}
    [Documentation]    Delete a pathpolicy for a vtn
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-path-policy:remove-path-policy    data={"input":{"id":"${policy_id}"}}
    Should Be Equal As Strings    ${resp.status_code}    200

Verify flowEntryPathPolicy
    [Arguments]    ${of_version}    ${port}    ${output}
    [Documentation]    Checking Flows on switch S1 and switch S3 after applying path policy
    ${DUMPFLOWS}=    Set Variable If    "${of_version}"=="OF10"    ${DUMPFLOWS_OF10}    ${DUMPFLOWS_OF13}
    write    ${DUMPFLOWS}
    ${result}    Read Until    mininet>
    Should Contain    ${result}    in_port=${port}    actions=${output}

Add a macmap
    [Arguments]    ${vtn_name}    ${vBridge_name}    ${src_add}    ${dst_add}
    [Documentation]    Create a macmap for a vbridge
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-mac-map:set-mac-map    data={"input":{"operation":"SET","allowed-hosts":["${dst_add}@0","${src_add}@0"],"tenant-name":"${vtn_name}","bridge-name":"${vBridge_name}"}}
    Should Be Equal As Strings    ${resp.status_code}    200

Get DynamicMacAddress
    [Arguments]    ${h}
    [Documentation]    Get Dynamic mac address of Host
    write    ${h} ifconfig -a | grep HWaddr
    ${source}    Read Until    mininet>
    ${HWaddress}=    Split String    ${source}    ${SPACE}
    ${sourceHWaddr}=    Get from List    ${HWaddress}    ${index}
    ${sourceHWaddress}=    Convert To Lowercase    ${sourceHWaddr}
    Return From Keyword    ${sourceHWaddress}    # Also [Return] would work here.

Mininet Ping Should Succeed
    [Arguments]    ${host1}    ${host2}
    [Documentation]    Ping hosts to check connectivity
    Write    ${host1} ping -c 1 ${host2}
    ${result}    Read Until    mininet>
    Should Contain    ${result}    64 bytes

Mininet Ping Should Not Succeed
    [Arguments]    ${host1}    ${host2}
    [Documentation]    Ping hosts when there is no connectivity and check hosts is unreachable
    Write    ${host1} ping -c 3 ${host2}
    ${result}    Read Until    mininet>
    Should Not Contain    ${result}    64 bytes

Start vlan_topo
    [Arguments]    ${OF}
    [Documentation]    Create custom topology for vlan functionality
    Clean Mininet System
    ${mininet_conn_id1}=    Open Connection    ${MININET}    prompt=${DEFAULT_LINUX_PROMPT}    timeout=30s
    Set Suite Variable    ${mininet_conn_id1}
    Login With Public Key    ${MININET_USER}    ${USER_HOME}/.ssh/${SSH_KEY}    any
    Execute Command    sudo ovs-vsctl set-manager ptcp:6644
    Put File    ${CURDIR}/${CREATE_VLAN_TOPOLOGY_FILE_PATH}
    Run Keyword If    '${OF}' == 'OF13'    Write    ${vlan_topo_13}
    ...    ELSE IF    '${OF}' == 'OF10'    Write    ${vlan_topo_10}
    ${result}    Read Until    mininet>

Get flow
    [Arguments]    ${vtn_name}
    [Documentation]    Get data flow.
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-flow-impl:vtn-flows/vtn-flow-table/${vtn_name}
    Should Be Equal As Strings    ${resp.status_code}    200

Remove a portmap
    [Arguments]    ${vtn_name}    ${vBridge_name}    ${interface_name}
    [Documentation]    Remove a portmap for a interface of a vbridge
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-port-map:remove-port-map    data={"input": {"tenant-name":${vtn_name},"bridge-name":${vBridge_name},"interface-name":${interface_name}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Verify FlowMacAddress
    [Arguments]    ${host1}    ${host2}    ${OF_VERSION}
    [Documentation]    Verify the source and destination mac address.
    Run Keyword If    '${OF_VERSION}' == 'OF10'    Verify Flows On OpenFlow    ${host1}    ${host2}    ${DUMPFLOWS_OF10}
    ...    ELSE    VerifyFlowsOnOpenFlow    ${host1}    ${host2}    ${DUMPFLOWS_OF13}

Verify Flows On OpenFlow
    [Arguments]    ${host1}    ${host2}    ${DUMPFLOWS}
    [Documentation]    Verify the mac addresses on the specified open flow.
    ${booleanValue}=    Run Keyword And Return Status    Verify macaddress    ${host1}    ${host2}    ${DUMPFLOWS}
    Should Be Equal As Strings    ${booleanValue}    True

Verify RemovedFlowMacAddress
    [Arguments]    ${host1}    ${host2}    ${OF_VERSION}
    [Documentation]    Verify the removed source and destination mac address.
    Run Keyword If    '${OF_VERSION}' == 'OF10'    Verify Removed Flows On OpenFlow    ${host1}    ${host2}    ${DUMPFLOWS_OF10}
    ...    ELSE    VerifyRemovedFlowsOnOpenFlow    ${host1}    ${host2}    ${DUMPFLOWS_OF13}

Verify Removed Flows On OpenFlow
    [Arguments]    ${host1}    ${host2}    ${DUMPFLOWS}
    [Documentation]    Verify the removed mac addresses on the specified open flow.
    ${booleanValue}=    Run Keyword And Return Status    Verify macaddress    ${host1}    ${host2}    ${DUMPFLOWS}
    Should Not Be Equal As Strings    ${booleanValue}    True

Verify macaddress
    [Arguments]    ${host1}    ${host2}    ${DUMPFLOWS}
    [Documentation]    Verify the source and destination mac address after ping in the dumpflows
    write    ${host1} ifconfig -a | grep HWaddr
    ${sourcemacaddr}    Read Until    mininet>
    ${macaddress}=    Split String    ${sourcemacaddr}    ${SPACE}
    ${sourcemacaddr}=    Get from List    ${macaddress}    ${index}
    ${sourcemacaddress}=    Convert To Lowercase    ${sourcemacaddr}
    write    ${host2} ifconfig -a | grep HWaddr
    ${destmacaddr}    Read Until    mininet>
    ${macaddress}=    Split String    ${destmacaddr}    ${SPACE}
    ${destmacaddr}=    Get from List    ${macaddress}    ${index}
    ${destmacaddress}=    Convert To Lowercase    ${destmacaddr}
    write    ${DUMPFLOWS}
    ${result}    Read Until    mininet>
    Should Contain    ${result}    ${sourcemacaddress}
    Should Contain    ${result}    ${destmacaddress}

Add a vtn flowfilter
    [Arguments]    ${vtn_name}    ${vtnflowfilter_data}
    [Documentation]    Create a flowfilter for a vtn
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-flow-filter:set-flow-filter   data={"input": {"tenant-name": "${vtn_name}",${vtnflowfilter_data}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a vbr flowfilter
    [Arguments]    ${vtn_name}    ${vBridge_name}    ${vbrflowfilter_data}
    [Documentation]    Create a flowfilter for a vbr
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-flow-filter:set-flow-filter    data={"input": {"tenant-name": "${vtn_name}", "bridge-name": "${vBridge_name}", ${vbrflowfilter_data}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Add a vbrif flowfilter
    [Arguments]    ${vtn_name}    ${vBridge_name}    ${interface_name}    ${vbrif_flowfilter_data}
    [Documentation]    Create a flowfilter for a vbrif
    ${resp}=    RequestsLibrary.Post Request    session     restconf/operations/vtn-flow-filter:set-flow-filter    data={"input": {"tenant-name": ${vtn_name}, "bridge-name": "${vBridge_name}","interface-name":"${interface_name}",${vbrif_flowfilter_data}}}
    Should Be Equal As Strings    ${resp.status_code}    200

Verify Flow Entry for Inet Flowfilter
    [Documentation]    Verify switch flow entry using flowfilter for a vtn
    ${booleanValue}=    Run Keyword And Return Status    Verify Actions on Flow Entry
    Should Not Be Equal As Strings    ${booleanValue}    True

Verify Removed Flow Entry for Inet Drop Flowfilter
    [Documentation]    Verify removed switch flow entry using flowfilter drop for a vtn
    ${booleanValue}=    Run Keyword And Return Status    Verify Actions on Flow Entry
    Should Be Equal As Strings    ${booleanValue}    True

Verify Actions on Flow Entry
    [Documentation]    check flow action elements by giving dumpflows in mininet
    write    ${DUMPFLOWS_OF13}
    ${result}    Read Until    mininet>
    : FOR    ${flowElement}    IN    @{FLOWELMENTS}
    \    should Contain    ${result}    ${flowElement}

Add a flowcondition
    [Arguments]    ${flowcond_name}
    [Documentation]    Create a flowcondition using Restconfig Api
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-flow-condition:set-flow-condition    data={"input":{"operation":"SET","present":"false","name":"${flowcond_name}", "vtn-flow-match":[{"vtn-ether-match":{"destination-address":"ba:bd:0f:e3:a8:c8","ether-type":"2048","source-address":"ca:9e:58:0c:1e:f0","vlan-id": "1"},"vtn-inet-match":{"source-network":"10.0.0.1/32","protocol":1,"destination-network":"10.0.0.2/32"},"index":"1"}]}}
    Should Be Equal As Strings    ${resp.status_code}    200

Get flowconditions
    [Documentation]    Retrieve the list of flowconditions created
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-flow-condition:vtn-flow-conditions
    Should Be Equal As Strings    ${resp.status_code}    200

Get flowcondition
    [Arguments]    ${flowcond_name}    ${retrieve}
    [Documentation]    Retrieve the flowcondition by name and to check the removed flowcondition we added "retrieve" argument to differentiate the status code,
    ...    since after removing flowcondition name the status will be different compare to status code when the flowcondition name is present.
    ${resp}=    RequestsLibrary.Get Request    session    restconf/operational/vtn-flow-condition:vtn-flow-conditions/vtn-flow-condition/${flowcond_name}
    Run Keyword If    '${retrieve}' == 'retrieve'    Should Be Equal As Strings    ${resp.status_code}    200
    ...    ELSE    Should Not Be Equal As Strings    ${resp.status_code}    200

Remove flowcondition
    [Arguments]    ${flowcond_name}
    [Documentation]    Remove the flowcondition by name
    ${resp}=    RequestsLibrary.Post Request    session    restconf/operations/vtn-flow-condition:remove-flow-condition    data={"input":{"name":"${flowcond_name}"}}
    Should Be Equal As Strings    ${resp.status_code}    200
