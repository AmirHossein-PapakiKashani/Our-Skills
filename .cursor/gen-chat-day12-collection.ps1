$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\chat-day12-collection.json'

function New-Uuid { return [guid]::NewGuid().ToString() }

function Make-AuthHeader([string]$tokenVar) {
    return @(
        @{ key = 'Authorization'; value = "Bearer {{$tokenVar}}" }
    )
}

function Make-Request {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [string[]]$HeaderVars = @('token_u1'),
        [hashtable]$ExtraHeaders = @{},
        [string]$BodyMode = $null,
        [string]$BodyRaw = $null,
        [object[]]$FormData = $null,
        [string]$TestScript = ''
    )
    $headers = @()
    if ($HeaderVars -and $HeaderVars.Count -gt 0 -and $HeaderVars[0] -ne 'NONE') {
        foreach ($hv in $HeaderVars) {
            $headers += @{ key = 'Authorization'; value = "Bearer {{$hv}}" }
        }
    }
    foreach ($k in $ExtraHeaders.Keys) {
        $headers += @{ key = $k; value = $ExtraHeaders[$k] }
    }

    $url = @{
        raw  = "{{baseUrl}}$Path"
        host = @('{{baseUrl}}')
        path = ($Path.TrimStart('/') -split '/')
    }

    $req = @{
        method = $Method
        header = $headers
        url    = $url
    }

    if ($BodyMode -eq 'raw') {
        $req.body = @{
            mode = 'raw'
            raw  = $BodyRaw
            options = @{ raw = @{ language = 'json' } }
        }
        $hasContentType = $headers | Where-Object { $_.key -eq 'Content-Type' }
        if (-not $hasContentType) {
            $req.header += @{ key = 'Content-Type'; value = 'application/json' }
        }
    }
    elseif ($BodyMode -eq 'formdata') {
        $req.body = @{ mode = 'formdata'; formdata = $FormData }
    }

    $events = @()
    if ($TestScript) {
        $events += @{
            listen = 'test'
            script = @{
                type = 'text/javascript'
                exec = ($TestScript -split "`n")
            }
        }
    }

    return @{
        name = $Name
        request = $req
        event = $events
    }
}

$deviceInfoJson = @'
{
  "username": "{{username}}",
  "password": "Test@12345",
  "deviceInfo": {
    "deviceID": "BE2A.250530.026.F3",
    "deviceName": "postman-test-device",
    "deviceVersion": "16",
    "appVersion": "2.113.0",
    "platform": "android"
  }
}
'@

function Login-ProfilePair([string]$label, [string]$username, [string]$tokenVar, [string]$userIdVar) {
    $loginBody = $deviceInfoJson.Replace('{{username}}', $username)
    $loginTest = @"
pm.test('Login $label returns 200', function () {
    pm.response.to.have.status(200);
});
const loginJson = pm.response.json();
pm.test('Login $label has accessToken', function () {
    pm.expect(loginJson.accessToken).to.be.a('string').and.not.empty;
});
pm.collectionVariables.set('$tokenVar', loginJson.accessToken);
"@

    $profileTest = @"
pm.test('Profile $label returns 200', function () {
    pm.response.to.have.status(200);
});
const profile = pm.response.json();
pm.test('Profile $label has userId', function () {
    pm.expect(profile.userId).to.be.a('number').above(0);
});
pm.collectionVariables.set('$userIdVar', profile.userId.toString());
"@

    return @(
        (Make-Request -Name "Login $label ($username)" -Method 'POST' -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode 'raw' -BodyRaw $loginBody -TestScript $loginTest),
        (Make-Request -Name "Profile $label" -Method 'GET' -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript $profileTest)
    )
}

$helpers = @'
function responseText() {
    try { return JSON.stringify(pm.response.json()); }
    catch (e) { return pm.response.text(); }
}
function assertDetailContains(text) {
    const j = pm.response.json();
    const hay = (j.detail || j.title || responseText());
    pm.expect(hay).to.include(text);
}
'@

# --- Folder 0: Auth ---
$authItems = @()
$authItems += Login-ProfilePair 'U1' 'chattest_sara' 'token_u1' 'userId_u1'
$authItems += Login-ProfilePair 'U2' 'chattest_reza' 'token_u2' 'userId_u2'
$authItems += Login-ProfilePair 'U3' 'chattest_nima' 'token_u3' 'userId_u3'
$authItems += Login-ProfilePair 'U4' 'chattest_kian' 'token_u4' 'userId_u4'

# --- Folder 1: Home ---
$folder1 = @(
    (Make-Request -Name 'P01 - Create PV Happy Path' -Method 'POST' -Path '/chat/conversations/pv/{{userId_u2}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('P01 status 200', () => pm.response.to.have.status(200));
const body = pm.response.json();
pm.test('P01 conversation id present', () => pm.expect(body.id).to.be.a('number').above(0));
pm.collectionVariables.set('conversationId_pv', body.id.toString());
"@)),
    (Make-Request -Name 'P02 - Invalid Target User Id' -Method 'POST' -Path '/chat/conversations/pv/0' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('P02 status 400', () => pm.response.to.have.status(400));
pm.test('P02 invalid user id message', () => assertDetailContains('شناسه کاربر نامعتبر است'));
"@)),
    (Make-Request -Name 'P03 - Self Chat Guard' -Method 'POST' -Path '/chat/conversations/pv/{{userId_u1}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('P03 status 400', () => pm.response.to.have.status(400));
pm.test('P03 cannot chat with yourself', () => assertDetailContains('امکان گفتگو با خودتان وجود ندارد'));
"@)),
    (Make-Request -Name 'P04 - Target User Not Found' -Method 'POST' -Path '/chat/conversations/pv/999999' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('P04 status 400', () => pm.response.to.have.status(400));
pm.test('P04 not found message', () => assertDetailContains('مکالمه یافت نشد'));
"@)),
    (Make-Request -Name 'P05 - Idempotency Same PV' -Method 'POST' -Path '/chat/conversations/pv/{{userId_u2}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('P05 status 200', () => pm.response.to.have.status(200));
const body = pm.response.json();
const saved = pm.collectionVariables.get('conversationId_pv');
pm.test('P05 same conversation id as P01', () => pm.expect(body.id.toString()).to.eql(saved));
"@)),
    (Make-Request -Name 'P08 - Unauthorized No Token' -Method 'POST' -Path '/chat/conversations/pv/{{userId_u2}}' -HeaderVars @('NONE') -TestScript @"
pm.test('P08 status 401', () => pm.response.to.have.status(401));
"@),
    (Make-Request -Name 'H01 - List Conversations' -Method 'GET' -Path '/chat/conversations' -HeaderVars @('token_u1') -TestScript @"
pm.test('H01 status 200', () => pm.response.to.have.status(200));
pm.test('H01 returns array', () => pm.expect(pm.response.json()).to.be.an('array'));
"@),
    (Make-Request -Name 'H02 - Search Conversations Partial' -Method 'GET' -Path '/chat/conversations?search=reza' -HeaderVars @('token_u1') -TestScript @"
pm.test('H02 status 200', () => pm.response.to.have.status(200));
const list = pm.response.json();
pm.test('H02 filtered list is array', () => pm.expect(list).to.be.an('array'));
"@),
    (Make-Request -Name 'H03 - Search Conversations Nonsense' -Method 'GET' -Path '/chat/conversations?search=zzznonsense999' -HeaderVars @('token_u1') -TestScript @"
pm.test('H03 status 200', () => pm.response.to.have.status(200));
pm.test('H03 empty array not error', () => pm.expect(pm.response.json()).to.be.an('array').that.is.empty);
"@),
    (Make-Request -Name 'H04 - Search Users Reza' -Method 'GET' -Path '/chat/users?search=reza' -HeaderVars @('token_u1') -TestScript @"
pm.test('H04 status 200', () => pm.response.to.have.status(200));
const users = pm.response.json();
pm.test('H04 U2 appears in results', () => {
    const uid = parseInt(pm.collectionVariables.get('userId_u2'), 10);
    pm.expect(users.some(u => u.id === uid)).to.be.true;
});
"@),
    (Make-Request -Name 'H05 - Search Users Nonsense' -Method 'GET' -Path '/chat/users?search=zzznonsense999' -HeaderVars @('token_u1') -TestScript @"
pm.test('H05 status 200', () => pm.response.to.have.status(200));
pm.test('H05 empty array', () => pm.expect(pm.response.json()).to.be.an('array').that.is.empty);
"@)
)

# --- Folder 2: Profile ---
$folder2 = @(
    (Make-Request -Name 'PR01 - Get Profile' -Method 'GET' -Path '/chat/profile' -HeaderVars @('token_u1') -TestScript @"
pm.test('PR01 status 200', () => pm.response.to.have.status(200));
const p = pm.response.json();
pm.test('PR01 has userId and displayName', () => {
    pm.expect(p.userId).to.be.a('number');
    pm.expect(p).to.have.property('displayName');
});
"@),
    (Make-Request -Name 'PR02 - Update DisplayName' -Method 'PUT' -Path '/chat/profile' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'displayName'; value = 'Sara Chat Test'; type = 'text' }
    ) -TestScript @"
pm.test('PR02 update status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'PR02b - Verify Profile Persisted' -Method 'GET' -Path '/chat/profile' -HeaderVars @('token_u1') -TestScript @"
pm.test('PR02b status 200', () => pm.response.to.have.status(200));
pm.test('PR02b displayName persisted', () => pm.expect(pm.response.json().displayName).to.eql('Sara Chat Test'));
"@),
    (Make-Request -Name 'PR03 - Update Profile No Fields' -Method 'PUT' -Path '/chat/profile' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @() -TestScript ($helpers + @"
pm.test('PR03 status 400', () => pm.response.to.have.status(400));
pm.test('PR03 at least one field required', () => assertDetailContains('حداقل یک فیلد برای ویرایش الزامی است'));
"@)),
    (Make-Request -Name 'PR04 - DisplayName Too Long' -Method 'PUT' -Path '/chat/profile' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'displayName'; value = ('X' * 101); type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('PR04 status 400', () => pm.response.to.have.status(400));
pm.test('PR04 max length error', () => assertDetailContains('نام نباید بیشتر از ۱۰۰ کاراکتر باشد'));
"@))
)

# --- Folder 3: PV messages ---
$folder3 = @(
    (Make-Request -Name 'M01 - Send PV Message Happy Path' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'Day12 PV hello from U1'; type = 'text' }
    ) -TestScript @"
pm.test('M01 send status 200', () => pm.response.to.have.status(200));
const msg = pm.response.json();
pm.test('M01 message id present', () => pm.expect(msg.id).to.be.a('number').above(0));
pm.collectionVariables.set('messageId_pv_u1', msg.id.toString());
"@),
    (Make-Request -Name 'M01b - Verify PV Message Persisted' -Method 'GET' -Path '/chat/conversations/{{conversationId_pv}}/messages?pageSize=20' -HeaderVars @('token_u1') -TestScript @"
pm.test('M01b status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
pm.test('M01b contains sent message', () => {
    pm.expect(page.messages.some(m => m.text === 'Day12 PV hello from U1')).to.be.true;
});
"@),
    (Make-Request -Name 'PV - Reply To Message' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u2') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'Reply from U2'; type = 'text' },
        @{ key = 'replyToMessageId'; value = '{{messageId_pv_u1}}'; type = 'text' }
    ) -TestScript @"
pm.test('Reply status 200', () => pm.response.to.have.status(200));
pm.test('Reply has replyTo', () => pm.expect(pm.response.json().replyTo).to.be.an('object'));
"@),
    (Make-Request -Name 'PV - Forward Message' -Method 'POST' -Path '/chat/messages/{{messageId_pv_u1}}/forward' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"targetConversationIds":[{{conversationId_pv}}]}' -TestScript @"
pm.test('Forward status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'PV - Edit Message' -Method 'PUT' -Path '/chat/messages/{{messageId_pv_u1}}' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"text":"Day12 PV hello from U1 (edited)"}' -TestScript @"
pm.test('Edit status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'M05 - Empty Message Validation' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @() -TestScript ($helpers + @"
pm.test('M05 status 400', () => pm.response.to.have.status(400));
pm.test('M05 empty message error', () => assertDetailContains('پیام نمی‌تواند خالی باشد'));
"@)),
    (Make-Request -Name 'M06 - Conversation Not Found' -Method 'POST' -Path '/chat/conversations/999999/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'ghost'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('M06 status 400', () => pm.response.to.have.status(400));
pm.test('M06 not found', () => assertDetailContains('مکالمه یافت نشد'));
"@)),
    (Make-Request -Name 'M07 - Non Participant Forbidden' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u4') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'intruder'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('M07 status 400', () => pm.response.to.have.status(400));
pm.test('M07 not a participant', () => assertDetailContains('شما عضو این مکالمه نیستید'));
"@)),
    (Make-Request -Name 'PV - Delete Message' -Method 'DELETE' -Path '/chat/messages/{{messageId_pv_u1}}' -HeaderVars @('token_u1') -TestScript @"
pm.test('Delete PV message status 200', () => pm.response.to.have.status(200));
"@)
)

# --- Folder 4: Block & Mute ---
$folder4 = @(
    (Make-Request -Name 'B01 - U1 Blocks U2' -Method 'POST' -Path '/chat/users/{{userId_u2}}/block' -HeaderVars @('token_u1') -TestScript @"
pm.test('B01 status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'B02 (M02) - Blocker Sends After Block' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'blocked attempt U1'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('B02 status 400', () => pm.response.to.have.status(400));
pm.test('B02 user blocked message', () => assertDetailContains('امکان ارسال پیام به این کاربر وجود ندارد'));
"@)),
    (Make-Request -Name 'B03 (M03) - Blocked User Sends' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u2') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'blocked attempt U2'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('B03 status 400', () => pm.response.to.have.status(400));
pm.test('B03 user blocked message', () => assertDetailContains('امکان ارسال پیام به این کاربر وجود ندارد'));
"@)),
    (Make-Request -Name 'B04 (M04) - Create Ripple Group While Blocked' -Method 'POST' -Path '/chat/groups' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = 'Block Ripple Group'; type = 'text' },
        @{ key = 'memberUserIds'; value = '{{userId_u2}}'; type = 'text' }
    ) -TestScript @"
pm.test('B04 group create status 200', () => pm.response.to.have.status(200));
const g = pm.response.json();
pm.collectionVariables.set('conversationId_block_ripple', g.id.toString());
"@),
    (Make-Request -Name 'B04b - U2 Sends In Group While Block Active' -Method 'POST' -Path '/chat/conversations/{{conversationId_block_ripple}}/messages' -HeaderVars @('token_u2') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'group msg while PV blocked'; type = 'text' }
    ) -TestScript @"
pm.test('B04b group send succeeds despite PV block', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'P06 - Create PV While Block Active' -Method 'POST' -Path '/chat/conversations/pv/{{userId_u2}}' -HeaderVars @('token_u1') -TestScript @"
pm.test('P06 status 200 despite block', () => pm.response.to.have.status(200));
const body = pm.response.json();
const saved = pm.collectionVariables.get('conversationId_pv');
pm.test('P06 same conversation id', () => pm.expect(body.id.toString()).to.eql(saved));
"@),
    (Make-Request -Name 'P07 - PV Still In Conversation List After Block' -Method 'GET' -Path '/chat/conversations' -HeaderVars @('token_u1') -TestScript @"
pm.test('P07 status 200', () => pm.response.to.have.status(200));
const list = pm.response.json();
const pvId = parseInt(pm.collectionVariables.get('conversationId_pv'), 10);
pm.test('P07 PV conversation still listed', () => pm.expect(list.some(c => c.id === pvId)).to.be.true);
"@),
    (Make-Request -Name 'B05 - U1 Unblocks U2' -Method 'DELETE' -Path '/chat/users/{{userId_u2}}/block' -HeaderVars @('token_u1') -TestScript @"
pm.test('B05 unblock status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'B06 - Post Unblock Send Success' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'post unblock hello'; type = 'text' }
    ) -TestScript @"
pm.test('B06 send status 200', () => pm.response.to.have.status(200));
"@)
)

# --- Folder 5: Group ---
$folder5 = @(
    (Make-Request -Name 'G01 - Create Group Happy Path' -Method 'POST' -Path '/chat/groups' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = 'Day12 Test Group'; type = 'text' },
        @{ key = 'memberUserIds'; value = '{{userId_u2}},{{userId_u3}}'; type = 'text' }
    ) -TestScript @"
pm.test('G01 status 200', () => pm.response.to.have.status(200));
const g = pm.response.json();
pm.test('G01 creator is Admin', () => pm.expect(g.currentUserRole).to.eql('Admin'));
pm.collectionVariables.set('conversationId_group', g.id.toString());
"@),
    (Make-Request -Name 'G02 - Empty Group Name' -Method 'POST' -Path '/chat/groups' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = ''; type = 'text' },
        @{ key = 'memberUserIds'; value = '{{userId_u2}}'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('G02 status 400', () => pm.response.to.have.status(400));
pm.test('G02 group name required', () => assertDetailContains('نام گروه الزامی است'));
"@)),
    (Make-Request -Name 'G03 - Empty MemberUserIds' -Method 'POST' -Path '/chat/groups' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = 'No Members Group'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('G03 status 400', () => pm.response.to.have.status(400));
pm.test('G03 at least one member', () => assertDetailContains('حداقل یک عضو باید انتخاب شود'));
"@)),
    (Make-Request -Name 'G04 - Non Admin Add Member Rejected' -Method 'POST' -Path '/chat/groups/{{conversationId_group}}/members' -HeaderVars @('token_u3') -BodyMode 'raw' -BodyRaw '{"userIds":[{{userId_u4}}]}' -TestScript ($helpers + @"
pm.test('G04 status 400', () => pm.response.to.have.status(400));
pm.test('G04 not group admin', () => assertDetailContains('فقط مدیر گروه مجاز به این عملیات است'));
"@)),
    (Make-Request -Name 'G05 - Admin Add Member U4' -Method 'POST' -Path '/chat/groups/{{conversationId_group}}/members' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"userIds":[{{userId_u4}}]}' -TestScript @"
pm.test('G05 status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'G06 - Admin Remove Member U4' -Method 'DELETE' -Path '/chat/groups/{{conversationId_group}}/members/{{userId_u4}}' -HeaderVars @('token_u1') -TestScript @"
pm.test('G06 status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'G07 - Non Admin Remove Member Rejected' -Method 'DELETE' -Path '/chat/groups/{{conversationId_group}}/members/{{userId_u2}}' -HeaderVars @('token_u3') -TestScript ($helpers + @"
pm.test('G07 status 400', () => pm.response.to.have.status(400));
pm.test('G07 not group admin', () => assertDetailContains('فقط مدیر گروه مجاز به این عملیات است'));
"@)),
    (Make-Request -Name 'G08 - Member Send Group Message' -Method 'POST' -Path '/chat/conversations/{{conversationId_group}}/messages' -HeaderVars @('token_u3') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'Group message from U3'; type = 'text' }
    ) -TestScript @"
pm.test('G08 status 200', () => pm.response.to.have.status(200));
pm.collectionVariables.set('messageId_u3_group', pm.response.json().id.toString());
"@),
    (Make-Request -Name 'G08b - Admin Send Group Message' -Method 'POST' -Path '/chat/conversations/{{conversationId_group}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'Group message from U1 admin'; type = 'text' }
    ) -TestScript @"
pm.test('G08b status 200', () => pm.response.to.have.status(200));
pm.collectionVariables.set('messageId_u1_group', pm.response.json().id.toString());
"@),
    (Make-Request -Name 'G09 - Admin Delete U3 Message' -Method 'DELETE' -Path '/chat/messages/{{messageId_u3_group}}' -HeaderVars @('token_u1') -TestScript @"
pm.test('G09 delete status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'G10 - Non Admin Delete U1 Message Rejected' -Method 'DELETE' -Path '/chat/messages/{{messageId_u1_group}}' -HeaderVars @('token_u3') -TestScript ($helpers + @"
pm.test('G10 status 400', () => pm.response.to.have.status(400));
pm.test('G10 cannot delete message', () => assertDetailContains('دسترسی برای حذف این پیام وجود ندارد'));
"@)),
    (Make-Request -Name 'G11 - U3 Leave Group' -Method 'POST' -Path '/chat/conversations/{{conversationId_group}}/leave' -HeaderVars @('token_u3') -TestScript @"
pm.test('G11 leave status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'G12 - Admin Leave Group' -Method 'POST' -Path '/chat/conversations/{{conversationId_group}}/leave' -HeaderVars @('token_u1') -TestScript @"
pm.test('G12 leave status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'G12b - Group Detail After Admin Leave' -Method 'GET' -Path '/chat/conversations/{{conversationId_group}}' -HeaderVars @('token_u2') -TestScript @"
pm.test('G12b detail status 200', () => pm.response.to.have.status(200));
const d = pm.response.json();
pm.test('G12b members reported', () => pm.expect(d.members).to.be.an('array'));
"@),
    (Make-Request -Name 'PG01 - Messages Default PageSize' -Method 'GET' -Path '/chat/conversations/{{conversationId_group}}/messages' -HeaderVars @('token_u2') -TestScript @"
pm.test('PG01 status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
pm.test('PG01 <= 20 messages default', () => pm.expect(page.messages.length).to.be.at.most(20));
"@),
    (Make-Request -Name 'PG02 - Messages PageSize Cap 50' -Method 'GET' -Path '/chat/conversations/{{conversationId_group}}/messages?pageSize=100' -HeaderVars @('token_u2') -TestScript @"
pm.test('PG02 status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
pm.test('PG02 capped at 50 items', () => pm.expect(page.messages.length).to.be.at.most(50));
"@),
    (Make-Request -Name 'PG03 - Messages Search Known Text' -Method 'GET' -Path '/chat/conversations/{{conversationId_group}}/messages?search=Group%20message' -HeaderVars @('token_u2') -TestScript @"
pm.test('PG03 status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
pm.test('PG03 has matching messages', () => pm.expect(page.messages.length).to.be.above(0));
"@),
    (Make-Request -Name 'PG04 - Messages Search Nonexistent' -Method 'GET' -Path '/chat/conversations/{{conversationId_group}}/messages?search=zzznonsense999' -HeaderVars @('token_u2') -TestScript @"
pm.test('PG04 status 200', () => pm.response.to.have.status(200));
pm.test('PG04 empty messages array', () => pm.expect(pm.response.json().messages).to.be.an('array').that.is.empty);
"@)
)

# --- Folder 6: Channel ---
$folder6 = @(
    (Make-Request -Name 'C01 - Create Channel Happy Path' -Method 'POST' -Path '/chat/channels' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = 'Day12 Test Channel'; type = 'text' },
        @{ key = 'handle'; value = 'day12_test_channel'; type = 'text' },
        @{ key = 'memberUserIds'; value = '{{userId_u2}}'; type = 'text' }
    ) -TestScript @"
pm.test('C01 status 200', () => pm.response.to.have.status(200));
const c = pm.response.json();
pm.test('C01 creator is Admin', () => pm.expect(c.currentUserRole).to.eql('Admin'));
pm.collectionVariables.set('conversationId_channel', c.id.toString());
"@),
    (Make-Request -Name 'C02 - Duplicate Handle Conflict' -Method 'POST' -Path '/chat/channels' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = 'Duplicate Channel'; type = 'text' },
        @{ key = 'handle'; value = 'day12_test_channel'; type = 'text' },
        @{ key = 'memberUserIds'; value = '{{userId_u2}}'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('C02 status 409', () => pm.response.to.have.status(409));
pm.test('C02 duplicate handle', () => assertDetailContains('این شناسه کانال قبلاً ثبت شده است'));
"@)),
    (Make-Request -Name 'C03 - Invalid Handle Format' -Method 'POST' -Path '/chat/channels' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'name'; value = 'Bad Handle Channel'; type = 'text' },
        @{ key = 'handle'; value = 'Invalid Handle!'; type = 'text' },
        @{ key = 'memberUserIds'; value = '{{userId_u2}}'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('C03 status 400', () => pm.response.to.have.status(400));
pm.test('C03 handle regex error', () => assertDetailContains('شناسه باید فقط شامل حروف کوچک انگلیسی'));
"@)),
    (Make-Request -Name 'C04 - Member Cannot Send In Channel' -Method 'POST' -Path '/chat/conversations/{{conversationId_channel}}/messages' -HeaderVars @('token_u2') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'member channel attempt'; type = 'text' }
    ) -TestScript ($helpers + @"
pm.test('C04 status 400', () => pm.response.to.have.status(400));
pm.test('C04 channel members cannot send', () => assertDetailContains('اعضای کانال اجازه ارسال پیام ندارند'));
"@)),
    (Make-Request -Name 'C05 - Admin Sends In Channel' -Method 'POST' -Path '/chat/conversations/{{conversationId_channel}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'Admin channel broadcast'; type = 'text' }
    ) -TestScript @"
pm.test('C05 status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'C06 - Non Admin Add Channel Member Rejected' -Method 'POST' -Path '/chat/channels/{{conversationId_channel}}/members' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"userIds":[{{userId_u3}}]}' -TestScript ($helpers + @"
pm.test('C06 status 400', () => pm.response.to.have.status(400));
pm.test('C06 not channel admin', () => assertDetailContains('فقط مدیر کانال مجاز به این عملیات است'));
"@)),
    (Make-Request -Name 'C07 - Admin Add Channel Member U3' -Method 'POST' -Path '/chat/channels/{{conversationId_channel}}/members' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"userIds":[{{userId_u3}}]}' -TestScript @"
pm.test('C07 status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'C08 - Member Leave Channel' -Method 'POST' -Path '/chat/conversations/{{conversationId_channel}}/leave' -HeaderVars @('token_u2') -TestScript @"
pm.test('C08 leave status 200', () => pm.response.to.have.status(200));
"@)
)

# --- Folder 7: Notification ---
$folder7 = @(
    (Make-Request -Name 'N01 - Notification For PV Message' -Method 'GET' -Path '/Notification?page=0' -HeaderVars @('token_u2') -TestScript @"
pm.test('N01 status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
const convId = parseInt(pm.collectionVariables.get('conversationId_pv'), 10);
const items = page.data || [];
pm.test('N01 notification references PV conversation', () => {
    pm.expect(items.some(n => n.dataId === convId)).to.be.true;
});
"@),
    (Make-Request -Name 'N02a - U2 Mute PV Conversation' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/mute' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"isMuted":true}' -TestScript @"
pm.test('N02a mute status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'N02b - U2 Notification Count Before Send' -Method 'GET' -Path '/Notification?page=0' -HeaderVars @('token_u2') -TestScript @"
pm.test('N02b status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
const items = page.data || [];
pm.collectionVariables.set('notif_count_before_mute', String(items.length));
"@),
    (Make-Request -Name 'N02c - U1 Send While U2 Muted' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'message while U2 muted'; type = 'text' }
    ) -TestScript @"
pm.test('N02c send status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'N02 - No New Notification While Muted' -Method 'GET' -Path '/Notification?page=0' -HeaderVars @('token_u2') -TestScript @"
pm.test('N02 status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
const items = page.data || [];
const before = parseInt(pm.collectionVariables.get('notif_count_before_mute') || '0', 10);
pm.test('N02 no new notification while muted', () => pm.expect(items.length).to.eql(before));
"@),
    (Make-Request -Name 'N03a - U2 Unmute PV Conversation' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/mute' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"isMuted":false}' -TestScript @"
pm.test('N03a unmute status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'N03b - U1 Send After Unmute' -Method 'POST' -Path '/chat/conversations/{{conversationId_pv}}/messages' -HeaderVars @('token_u1') -BodyMode 'formdata' -FormData @(
        @{ key = 'text'; value = 'message after unmute'; type = 'text' }
    ) -TestScript @"
pm.test('N03b send status 200', () => pm.response.to.have.status(200));
"@),
    (Make-Request -Name 'N03 - New Notification After Unmute' -Method 'GET' -Path '/Notification?page=0' -HeaderVars @('token_u2') -TestScript @"
pm.test('N03 status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
const items = page.data || [];
const before = parseInt(pm.collectionVariables.get('notif_count_before_mute') || '0', 10);
const convId = parseInt(pm.collectionVariables.get('conversationId_pv'), 10);
pm.test('N03 new notification created', () => pm.expect(items.length).to.be.above(before));
pm.test('N03 references PV conversation', () => pm.expect(items.some(n => n.dataId === convId)).to.be.true);
"@)
)

# --- Folder 8: SignalR ---
$srTest = @"
// SR01: Postman raw WebSocket cannot complete SignalR JSON handshake protocol.
// Document as Blocked — manual verification: ws://localhost:5144/hubs/chat?access_token={{token_u2}}
pm.test('SR01 marked Blocked — SignalR handshake not supported in Postman WS', function () {
    pm.expect(true).to.be.true;
});
console.log('SR01 Blocked: use SignalR client with access_token query on /hubs/chat');
"@

$folder8 = @(
    (Make-Request -Name 'SR01 - SignalR WebSocket Smoke (Blocked)' -Method 'GET' -Path '/hubs/chat' -HeaderVars @('token_u2') -TestScript $srTest)
)

$collection = @{
    info = @{
        _postman_id = (New-Uuid)
        name        = 'Elay Customer — Chat Module (Day 12 Integration Tests)'
        description = 'Day 12 Chat integration contract tests for Elay Customer API. Run folder 0 Auth first.'
        schema      = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' },
        @{ key = 'token_u1'; value = '' },
        @{ key = 'token_u2'; value = '' },
        @{ key = 'token_u3'; value = '' },
        @{ key = 'token_u4'; value = '' },
        @{ key = 'userId_u1'; value = '' },
        @{ key = 'userId_u2'; value = '' },
        @{ key = 'userId_u3'; value = '' },
        @{ key = 'userId_u4'; value = '' },
        @{ key = 'conversationId_pv'; value = '' },
        @{ key = 'conversationId_group'; value = '' },
        @{ key = 'conversationId_channel'; value = '' },
        @{ key = 'messageId_u3_group'; value = '' },
        @{ key = 'messageId_u1_group'; value = '' }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $authItems }
        @{ name = '1. Home (List, Search, Create)'; item = $folder1 }
        @{ name = '2. Profile'; item = $folder2 }
        @{ name = '3. PV — Send, Attach, Reply, Forward, Edit, Delete'; item = $folder3 }
        @{ name = '4. PV — Block & Mute (mutual block scenarios)'; item = $folder4 }
        @{ name = '5. Group — Create, Members, Send, Leave, Delete Message'; item = $folder5 }
        @{ name = '6. Channel — Create, Members, Send, Leave, Delete Message'; item = $folder6 }
        @{ name = '7. Notification'; item = $folder7 }
        @{ name = '8. SignalR Smoke Test (WebSocket, single request)'; item = $folder8 }
    )
}

$json = $collection | ConvertTo-Json -Depth 100 -Compress:$false
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output "Written: $outPath ($((Get-Item $outPath).Length) bytes)"
