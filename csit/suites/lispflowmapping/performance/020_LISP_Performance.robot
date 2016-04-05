*** Settings ***
Documentation     LISP performance tests for maximum and lossless southbound serving rates
Suite Setup       Prepare Environment
Suite Teardown    Destroy Environment
Library           Collections
Library           DateTime
Library           OperatingSystem
Library           RequestsLibrary
Library           String
Resource          ../../../libraries/Utils.robot
Resource          ../../../libraries/LISPFlowMapping.robot
Variables         ../../../variables/Variables.py

*** Variables ***
# The number of "lossy" tests to perform (each tests will output results)
# Default 10
${LOSSY_TEST_CNT}    10
# The number of different EID-to-RLOC mappings to generate for request and registration
# Default 10.000
${MAPPINGS}       10000
# The replay rate in packets/second (as a parameter to 'udpreplay') for the "lossy" tests
# Default 100.000
${REPLAY_PPS}     100000
# The amount of times a pcap file should be replayed by 'udpreplay' for the "lossy" tests
# Default 1000
${REPLAY_CNT}     1000
# Starting packet rate for the Map-Request "lossless" tests
${REPLAY_PPS_MREQ_START}    30000
# End packet rate for the Map-Request "lossless" tests
${REPLAY_PPS_MREQ_END}    50000
# Starting packet rate for the Map-Register "lossless" tests
${REPLAY_PPS_MREG_START}    3000
# End packet rate for the Map-Register "lossless" tests
${REPLAY_PPS_MREG_END}    6000
# Packet rate increment for the "lossless" tests
${REPLAY_PPS_INCREMENT}    100
${LISP_SCAPY}     https://raw.githubusercontent.com/ljakab/py-lispnetworking/opendaylight/lisp.py
${TOOLS_DIR}      ${CURDIR}/../../../../tools/odl-lispflowmapping-performance-tests/
${PCAP_CREATOR}    ${TOOLS_DIR}/create_lisp_control_plane_pcap.py
${MAPPING_BLASTER}    ${TOOLS_DIR}/mapping_blaster.py
${REPLAY_FILE_MREQ}    encapsulated-map-requests-sequential.pcap
${REPLAY_FILE_MREG}    map-registers-sequential-no-auth.pcap
${REPLAY_FILE_MRGA}    map-registers-sequential-sha1-auth.pcap
${RPCS_RESULTS_FILE}    rpcs.csv
${PPS_RESULTS_FILE}    pps.csv
${LOSSLESS_RESULTS_FILE_MREQ}    lossless_map_request.csv
${LOSSLESS_RESULTS_FILE_MREG}    lossless_map_register.csv

*** Test Cases ***
Add Simple IPv4 Mappings
    Clear Northbound Database
    ${start_date}=    Get Current Date
    Run Process With Logging And Status Check    ${MAPPING_BLASTER}    --host    ${ODL_SYSTEM_IP}    --mappings    ${MAPPINGS}
    ${end_date}=    Get Current Date
    ${add_seconds}=    Subtract Date From Date    ${end_date}    ${start_date}
    Log    ${add_seconds}
    ${rpcs}=    Evaluate    int(${MAPPINGS}/${add_seconds})
    Log    ${rpcs}
    Append To File    ${RPCS_RESULTS_FILE}    ${rpcs}\n

Warmup
    All Lossy Tests

Lossy Test Loop
    Repeat Keyword    ${LOSSY_TEST_CNT}    All Lossy Tests With Save

Map-Request Lossless Test Loop
    : FOR    ${INDEX}    IN RANGE    ${REPLAY_PPS_MREQ_START}/${REPLAY_PPS_INCREMENT}    ${REPLAY_PPS_MREQ_END}/${REPLAY_PPS_INCREMENT}
    \    Log    ${INDEX}
    \    ${test_pps}=    Evaluate    ${INDEX}*${REPLAY_PPS_INCREMENT}
    \    ${loss_percent}=    Lossless Test    2    ${REPLAY_FILE_MREQ}    ${test_pps}
    \    Append To File    ${LOSSLESS_RESULTS_FILE_MREQ}    ${test_pps},${loss_percent}\n

Map-Register Lossless Test Loop
    Allow Unauthenticated Map-Registers
    : FOR    ${INDEX}    IN RANGE    ${REPLAY_PPS_MREG_START}/${REPLAY_PPS_INCREMENT}    ${REPLAY_PPS_MREG_END}/${REPLAY_PPS_INCREMENT}
    \    Log    ${INDEX}
    \    ${test_pps}=    Evaluate    ${INDEX}*${REPLAY_PPS_INCREMENT}
    \    ${loss_percent}=    Lossless Test    4    ${REPLAY_FILE_MREG}    ${test_pps}
    \    Append To File    ${LOSSLESS_RESULTS_FILE_MREG}    ${test_pps},${loss_percent}\n

*** Keywords ***
Clear Northbound Database
    ${resp}=    RequestsLibrary.Delete Request    session    /restconf/config/odl-mappingservice:mapping-database
    Log    ${resp.content}

Clear Southbound Database
    ${resp}=    RequestsLibrary.Delete Request    session    /restconf/operational/odl-mappingservice:mapping-database
    Log    ${resp.content}

All Lossy Tests With Save
    ${result}=    All Lossy Tests
    Append To File    ${PPS_RESULTS_FILE}    ${result}

All Lossy Tests
    ${pps_mrep}=    Lossy Test    2    ${REPLAY_FILE_MREQ}
    Clear Southbound Database
    Allow Unauthenticated Map-Registers
    ${pps_mnot}=    Lossy Test    4    ${REPLAY_FILE_MREG}
    [Return]    ${pps_mrep},${pps_mnot}\n

Lossy Test
    [Arguments]    ${lisp_type}    ${replay_file}
    [Documentation]    This tests will send traffic at a rate that is known to be
    ...    than the capacity of the LISP Flow Mapping service and count the reply
    ...    messages. Using the test's time duration, it computes the average reply
    ...    packet rate in packets per second
    ${elapsed_time}=    Generate Test Traffic    ${REPLAY_PPS}    ${REPLAY_CNT}    ${replay_file}
    ${odl_tx_count}=    Get Control Message Stats    ${lisp_type}    tx-count
    ${pps}=    Evaluate    int(${odl_tx_count}/${elapsed_time})
    Log    ${pps}
    [Return]    ${pps}

Lossless Test
    [Arguments]    ${lisp_type}    ${replay_file}    ${replay_pps}
    [Documentation]    This test will send traffic at a configurable rate in such
    ...    a way that the test duration will be approximately 100 seconds. It will
    ...    then compare the number of packets sent with the number of packets
    ...    received, and compute the packet loss rate in percent.
    ${replay_cnt}=    Evaluate    int(${replay_pps}*100/float(${MAPPINGS}))+1
    ${elapsed_time}=    Generate Test Traffic    ${replay_pps}    ${replay_cnt}    ${replay_file}
    Log    ${elapsed_time}
    ${packets_sent}=    Evaluate    ${MAPPINGS}*${replay_cnt}
    Log    ${packets_sent}
    ${packets_rcvd}=    Get Control Message Stats    ${lisp_type}    tx-count
    Log    ${packets_rcvd}
    ${loss_percent}=    Evaluate    (1 - (${packets_rcvd}/float(${packets_sent}))) * 100
    [Return]    ${loss_percent}

Generate Test Traffic
    [Arguments]    ${replay_pps}    ${replay_cnt}    ${replay_file}
    Reset Stats
    ${result}=    Run Process With Logging And Status Check    /usr/local/bin/udpreplay    --pps    ${replay_pps}    --repeat    ${replay_cnt}
    ...    --host    ${ODL_SYSTEM_IP}    --port    4342    ${replay_file}
    ${partial}=    Fetch From Left    ${result.stdout}    s =
    Log    ${partial}
    ${time}=    Fetch From Right    ${partial}    ${SPACE}
    ${time}=    Convert To Number    ${time}
    Log    ${time}
    [Return]    ${time}

Reset Stats
    ${resp}=    RequestsLibrary.Post Request    session    ${LFM_SB_RPC_API}:reset-stats
    Log    ${resp.content}
    Should Be Equal As Strings    ${resp.status_code}    200

Allow Unauthenticated Map-Registers
    ${add_key}=    OperatingSystem.Get File    ${JSON_DIR}/rpc_add-key_default.json
    ${resp}=    RequestsLibrary.Post Request    session    ${LFM_RPC_API}:add-key    ${add_key}
    Log    ${resp.content}

Get Control Message Stats
    [Arguments]    ${lisp_type}    ${stat_type}
    ${resp}=    RequestsLibrary.Post Request    session    ${LFM_SB_RPC_API}:get-stats
    Log    ${resp.content}
    ${output}=    Get From Dictionary    ${resp.json()}    output
    ${stats}=    Get From Dictionary    ${output}    control-message-stats
    ${ctrlmsg}=    Get From Dictionary    ${stats}    control-message
    ${ctrlmsg_type}=    Get From List    ${ctrlmsg}    ${lisp_type}
    ${msg_cnt}=    Get From Dictionary    ${ctrlmsg_type}    ${stat_type}
    ${msg_cnt}=    Convert To Integer    ${msg_cnt}
    Log    ${msg_cnt}
    [Return]    ${msg_cnt}

Prepare Environment
    Create File    ${RPCS_RESULTS_FILE}    store/s\n
    Create File    ${PPS_RESULTS_FILE}    replies/s,notifies/s\n
    Create File    ${LOSSLESS_RESULTS_FILE_MREQ}    pps,loss\n
    Create File    ${LOSSLESS_RESULTS_FILE_MREG}    pps,loss\n
    Create Session    session    http://${ODL_SYSTEM_IP}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS}
    Run Process With Logging And Status Check    wget    -P    ${TOOLS_DIR}    ${LISP_SCAPY}
    Run Process With Logging And Status Check    ${PCAP_CREATOR}    --requests    ${MAPPINGS}

Destroy Environment
    Delete All Sessions
    Remove File    ${TOOLS_DIR}/lisp.py*
    Remove File    ${REPLAY_FILE_MREQ}
    Remove File    ${REPLAY_FILE_MREG}
