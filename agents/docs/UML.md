# Senapath - UML Diagrams

Dokumen ini berisi diagram UML yang menjelaskan arsitektur dan perilaku sistem Senapath secara ringkas namun lengkap. Diagram menggunakan PlantUML dan dapat dirender dengan ekstensi editor atau PlantUML Server.

**Daftar diagram:**
1. Use Case Diagram - aktor dan fitur utama
2. Use Case Scenarios - skenario pengguna utama
3. Activity Diagram - alur perekaman perjalanan
4. Class Diagram - struktur domain dan data
5. Sequence Diagram - interaksi komponen utama

---

## 1. Use Case Diagram

```plantuml
@startuml
left to right direction
skinparam actorStyle awesome

actor "Cyclist" as Rider
actor "GPS/Sensor" as GPS
actor "Supabase Cloud" as Cloud
actor "Gemini AI" as AI
actor "Blockchain" as Chain

rectangle "Senapath System" {
  ' Core ride features
  usecase "Record Ride" as UC1
  usecase "Pause/Resume Session" as UC2
  usecase "View History" as UC3
  usecase "Manage GPX Routes" as UC4
  usecase "Navigate Route" as UC5
  
  ' Training & analysis
  usecase "View Progress & Stats" as UC6
  usecase "Set Training Goals" as UC7
  usecase "Create Workout Intervals" as UC8
  usecase "AI Chat Assistant" as UC9
  usecase "AI Ride Coaching" as UC10
  
  ' Profile & settings
  usecase "Manage Profile" as UC11
  usecase "Emergency Contacts" as UC12
  usecase "Cloud Account Auth" as UC13
  usecase "Sync Sessions to Cloud" as UC14
  
  ' Social & competition
  usecase "Join Cycling Team" as UC15
  usecase "Share Ride Summary" as UC16
  usecase "View Leaderboard" as UC17
  
  ' Proof & verification
  usecase "Generate Proof Chain" as UC18
  usecase "Anchor to Blockchain" as UC19
  usecase "Verify Proof" as UC20
  
  ' Logistics
  usecase "Currency Converter" as UC21
  usecase "Timezone Converter" as UC22
}

' Relationships
Rider --> UC1
Rider --> UC2
Rider --> UC3
Rider --> UC4
Rider --> UC5
Rider --> UC6
Rider --> UC7
Rider --> UC8
Rider --> UC9
Rider --> UC10
Rider --> UC11
Rider --> UC12
Rider --> UC13
Rider --> UC15
Rider --> UC16
Rider --> UC17
Rider --> UC19
Rider --> UC20
Rider --> UC21
Rider --> UC22

GPS --> UC1
GPS --> UC5
Cloud --> UC13
Cloud --> UC14
Cloud --> UC15
Cloud --> UC17
AI --> UC9
AI --> UC10
Chain --> UC19

UC1 ..> UC18 : <<include>>
UC1 ..> UC14 : <<extend>>
UC18 ..> UC19 : <<extend>>
UC5 ..> UC10 : <<extend>>
UC15 ..> UC16 : <<extend>>

@enduml
```

---

## 2. Use Case Scenarios

### Scenario 1: Recording a Ride Session
**Actor:** Cyclist  
**Precondition:** GPS and location permissions granted  
**Main Flow:**
1. Cyclist opens app and navigates to Session screen
2. System checks location permission and GPS availability
3. Cyclist optionally selects a GPX route to follow
4. Cyclist presses "Start Recording"
5. System creates session record in local database (Drift)
6. System starts GPS and sensor streams (location, barometer, accelerometer)
7. System records telemetry points (encrypted AES-256-GCM)
8. Cyclist can pause/resume during ride
9. Cyclist finishes ride
10. System stops streams, calculates summary (distance, duration, elevation)
11. System generates cryptographic proof block and appends to local chain
12. If auto-sync enabled and user signed in, system uploads summary to cloud
13. System displays ride summary

**Alternative Flow:**
- 4a. GPS not ready → System shows warning, cyclist can retry or proceed with limited tracking
- 8a. App backgrounded → System continues recording via foreground service (Android) or background location (iOS)
- 12a. No internet → Session remains local with "pending sync" status

**Postcondition:** Ride session saved locally, proof chain updated, optionally synced to cloud

---

### Scenario 2: Cloud Authentication & Sync
**Actor:** Cyclist  
**Precondition:** Supabase configured, internet available  
**Main Flow:**
1. Cyclist opens "Account & Security"
2. Cyclist enters email and password
3. System sends credentials to custom auth Edge Function `app-auth`
4. Edge Function verifies PBKDF2-SHA256 password hash
5. Edge Function generates JWT (HS256, aud=authenticated, sub=user_id)
6. Edge Function creates refresh token (rotated, hash stored in DB)
7. System stores tokens in secure storage (flutter_secure_storage)
8. System loads user profile and syncs pending sessions
9. Cyclist can enable biometric unlock for stored session

**Alternative Flow:**
- 4a. Invalid credentials → Error displayed, retry allowed
- 6a. Rate limit exceeded → Temporary lockout message
- 9a. User signs out → Tokens cleared, local data retained

**Postcondition:** User authenticated, sessions synced, biometric unlock available

---

### Scenario 3: Blockchain Proof Anchoring
**Actor:** Cyclist  
**Precondition:** Completed rides exist, user signed in, internet available  
**Main Flow:**
1. Cyclist opens "Ride Proofs"
2. System displays local proof chain blocks
3. System verifies chain integrity (hash linkage)
4. Cyclist presses "Anchor to Blockchain"
5. System syncs all blocks to Supabase
6. System calls Edge Function `anchor-ride-proofs`
7. Edge Function checks rate limit (10 min) and head hash uniqueness
8. Edge Function creates anchor record (status=pending)
9. Server-side relayer signs transaction with calldata `senapath:v1:<count>:<hash>`
10. Relayer sends 0 ETH transaction to Ethereum Sepolia via JSON-RPC
11. Edge Function waits for receipt
12. If success, updates anchor (status=confirmed, txHash, blockNumber)
13. Cyclist can view txHash on Sepolia explorer
14. Cyclist presses "Verify" to independently check via public RPC
15. System reads transaction and receipt, compares calldata and sender
16. System displays verification status (verified/pending/mismatch)

**Alternative Flow:**
- 7a. Rate limit hit or duplicate head → Returns existing anchor
- 10a. Transaction fails → status=failed, error logged
- 14a. Transaction not yet mined → status=pending

**Postcondition:** Proof head hash immutably recorded on blockchain, verifiable independently

---

### Scenario 4: Joining a Cycling Team
**Actor:** Cyclist  
**Precondition:** User signed in to cloud account  
**Main Flow:**
1. Cyclist navigates to "My Teams"
2. Cyclist presses "Join Team"
3. Cyclist enters 32-character hex invite code
4. System calls Supabase RPC `join_cycling_team`
5. RPC validates code format and checks team existence
6. RPC inserts member record with role=member
7. System displays team dashboard with members list
8. Cyclist can share completed ride summaries to team
9. Team members see shared rides (no GPS coordinates, only summary)

**Alternative Flow:**
- 5a. Invalid code → Error message
- 8a. Cyclist unshares or leaves team → Summary link removed from team view

**Postcondition:** Cyclist is team member, can share rides to team

---

### Scenario 5: AI Chat Assistant
**Actor:** Cyclist  
**Precondition:** User signed in, Gemini API configured, daily quota available  
**Main Flow:**
1. Cyclist opens "AI Assistant"
2. Cyclist types question about training or routes
3. System sends message to Edge Function `rider-assistant`
4. Edge Function verifies JWT and extracts user ID
5. Edge Function calls PostgreSQL function `consume_ai_chat_quota`
6. If quota available (30/day), Edge Function calls Gemini API
7. Gemini returns response
8. Edge Function returns answer to app
9. System displays answer in chat

**Alternative Flow:**
- 5a. Quota exhausted → HTTP 429, system shows "daily limit reached"
- 6a. Gemini error → System shows error message
- Context options: User can include local routes or preferences (with consent)

**Postcondition:** Cyclist receives AI-generated response, quota decremented

---

## 3. Activity Diagram

```plantuml
@startuml
title Ride Recording & Sync Flow

start
:Open app;

if (Cloud configured?) then (yes)
  if (Session stored?) then (yes)
    :Restore & refresh token;
  else (no)
    :Show sign-in screen;
  endif
else (no)
  :Local-only mode;
endif

:Navigate to Session;
:Check permissions;

if (Location & GPS ready?) then (no)
  :Show warning;
  stop
endif

:Create session (status=recording);
:Start GPS & sensor streams;

partition Recording {
  repeat
    :Receive GPS sample;
    :Encrypt telemetry (AES-GCM);
    :Save to Drift database;
    
    if (User pauses?) then (yes)
      :Update status=paused;
      :Stop streams;
      
      if (Resume?) then (yes)
        :Restart streams;
      endif
    endif
  repeat while (Not finished?)
}

:Stop all streams;
:Calculate summary;
:Update status=completed;

:Append proof block to chain;
:Save ride history features (for KNN);

if (Auto-sync enabled AND signed in?) then (yes)
  fork
    :Upload summary to cloud;
  fork again
    :Continue local operations;
  endfork
  
  if (Upload success?) then (yes)
    :Mark syncStatus=synced;
  else (no)
    :Mark syncStatus=pending;
  endif
endif

:Display ride summary;
stop

@enduml
```

---

## 4. Class Diagram

```plantuml
@startuml
title Core Domain & Data Architecture

skinparam classAttributeIconSize 0
hide circle

package "Domain Models" {
  class RideSessionSnapshot {
    +id: String
    +title: String
    +activityType: ActivityType
    +startedAt: DateTime
    +endedAt: DateTime?
    +status: RideSessionStatus
    +syncStatus: String
    +distanceMeters: double
    +durationSeconds: int
  }
  
  class TelemetryLocation {
    +recordedAt: DateTime
    +latitude: double
    +longitude: double
    +accuracyMeters: double
    +altitudeMeters: double?
    +speedMetersPerSecond: double?
  }
  
  class RideLedgerBlock {
    +index: int
    +sessionId: String
    +createdAt: DateTime
    +distanceMeters: double
    +durationSeconds: int
    +previousHash: String
    +hash: String
  }
  
  class CyclingTeam {
    +id: String
    +name: String
    +inviteCode: String
    +createdAt: DateTime
  }
}

package "Repositories" {
  interface RideSessionRepository {
    +start(DateTime): RideSessionSnapshot
    +pause(id, DateTime)
    +resume(id, DateTime)
    +finish(id, DateTime)
    +recordLocation(id, TelemetryLocation)
    +loadCompletedSessions()
  }
  
  class DriftRideSessionRepository {
    -database: AppDatabase
    -codec: EncryptedTelemetryCodec
  }
  
  class RideLedgerRepository {
    -database: AppDatabase
    +loadBlocks(): List<RideLedgerBlock>
    +appendSession(session)
    +verifyChain(): bool
  }
  
  class CyclingTeamRepository {
    +joinTeam(inviteCode)
    +leaveTeam(teamId)
    +shareRide(teamId, sessionId)
    +unshareRide(shareId)
  }
}

package "Presentation" {
  class RideSessionCubit {
    +start(route?, workout?)
    +pause()
    +resume()
    +finish()
    +state: RideSessionState
  }
  
  class CloudAccountCubit {
    +signIn(email, password)
    +signUp(email, password)
    +signOut()
    +state: CloudAccountState
  }
  
  class RideLedgerCubit {
    +load()
    +sync()
    +anchor()
    +verifyAnchor(anchor)
    +state: RideLedgerState
  }
  
  class CyclingTeamCubit {
    +loadTeams()
    +joinTeam(code)
    +shareRide(teamId, sessionId)
    +state: CyclingTeamState
  }
}

package "Cloud Gateways" {
  interface CloudAccountGateway {
    +isConfigured: bool
    +isSignedIn: bool
    +signIn(email, password)
    +signUp(email, password)
  }
  
  class SupabaseCloudAccountGateway {
    -sessionManager: CustomAuthSessionManager
  }
  
  class CustomAuthSessionManager {
    +currentUserId: String?
    +requireAccessToken(): String
    +invokeAuthenticatedFunction(name, body)
  }
  
  interface RideLedgerSyncGateway {
    +sync(blocks)
    +anchor()
    +anchors()
  }
  
  class SupabaseRideLedgerSyncGateway
}

package "Storage" {
  class AppDatabase {
    +schemaVersion: int
    +rideSessions
    +telemetryPoints
    +savedRoutes
    +rideHistory
    +appPreferences
  }
  
  interface SecureVault {
    +read(key): String?
    +write(key, value)
    +delete(key)
  }
  
  class EncryptedTelemetryCodec {
    +encode(TelemetryLocation): Uint8List
    +decode(Uint8List): TelemetryLocation
  }
}

' Relationships
RideSessionCubit --> RideSessionRepository
RideSessionCubit --> RideLedgerRepository
CloudAccountCubit --> CloudAccountGateway
RideLedgerCubit --> RideLedgerRepository
RideLedgerCubit --> RideLedgerSyncGateway
CyclingTeamCubit --> CyclingTeamRepository

DriftRideSessionRepository ..|> RideSessionRepository
DriftRideSessionRepository --> AppDatabase
DriftRideSessionRepository --> EncryptedTelemetryCodec
EncryptedTelemetryCodec --> SecureVault

SupabaseCloudAccountGateway ..|> CloudAccountGateway
SupabaseCloudAccountGateway --> CustomAuthSessionManager
CustomAuthSessionManager --> SecureVault

SupabaseRideLedgerSyncGateway ..|> RideLedgerSyncGateway
SupabaseRideLedgerSyncGateway --> CustomAuthSessionManager

RideLedgerRepository --> AppDatabase
CyclingTeamRepository --> CustomAuthSessionManager

@enduml
```

---

## 5. Sequence Diagram

### 5.1 Authentication & Startup

```plantuml
@startuml
title Custom Authentication Flow

actor Cyclist
participant "CloudAccountScreen" as UI
participant "CloudAccountCubit" as Cubit
participant "SupabaseCloudAccountGateway" as Gateway
participant "CustomAuthSessionManager" as Session
participant "app-auth\nEdge Function" as Auth
participant "PostgreSQL" as DB
participant "SecureVault" as Vault

Cyclist -> UI: Open app
UI -> Cubit: initialize()
Cubit -> Gateway: restoreSession()
Gateway -> Session: restore()
Session -> Vault: read tokens

alt Session exists
  Vault --> Session: access + refresh tokens
  Session -> Auth: POST action=refresh
  Auth -> DB: rotate_app_auth_session()
  DB --> Auth: new tokens
  Auth --> Session: JWT + new refresh token
  Session -> Vault: store new tokens
  Session --> Cubit: signed in
  Cubit --> UI: Show home
else No session
  Vault --> Session: null
  Session --> Cubit: not signed in
  Cubit --> UI: Show sign-in form
  
  Cyclist -> UI: Enter email & password
  UI -> Cubit: signIn(email, password)
  Cubit -> Gateway: signIn()
  Gateway -> Session: signIn()
  Session -> Auth: POST action=sign-in
  Auth -> DB: SELECT app_users WHERE email
  Auth -> Auth: Verify PBKDF2-SHA256 hash
  
  alt Valid credentials
    Auth -> DB: INSERT/UPDATE refresh session
    DB --> Auth: session created
    Auth --> Session: JWT + refresh token
    Session -> Vault: store tokens
    Session --> Cubit: signed in
    Cubit --> UI: Navigate to home
  else Invalid credentials
    Auth --> Session: HTTP 401
    Session --> Cubit: auth error
    Cubit --> UI: Show error message
  end
end

@enduml
```

---

### 5.2 Recording Ride Session

```plantuml
@startuml
title Record Ride Session

actor Cyclist
participant "SessionScreen" as UI
participant "RideSessionCubit" as Cubit
participant "GPS & Sensors" as GPS
participant "DriftRideSessionRepository" as Repo
participant "EncryptedTelemetryCodec" as Codec
participant "AppDatabase" as DB
participant "RideLedgerRepository" as Ledger

Cyclist -> UI: Press Start
UI -> Cubit: start(route?, workout?)
Cubit -> Cubit: Check permissions
Cubit -> Repo: start(now)
Repo -> DB: INSERT ride_sessions\nstatus=recording
DB --> Repo: session created
Repo --> Cubit: RideSessionSnapshot

Cubit -> GPS: Subscribe to location stream
activate GPS

loop While recording
  GPS -> Cubit: Location update
  Cubit -> Repo: recordLocation(id, location)
  Repo -> Codec: encode(location)
  Codec -> Codec: Encrypt with AES-256-GCM
  Codec --> Repo: ciphertext
  Repo -> DB: INSERT telemetry_points
  Cubit -> UI: Update metrics\n(distance, speed, elevation)
end

alt User pauses
  Cyclist -> UI: Press Pause
  UI -> Cubit: pause()
  Cubit -> GPS: Unsubscribe stream
  deactivate GPS
  Cubit -> Repo: pause(id, now)
  Repo -> DB: UPDATE pausedAt
  
  Cyclist -> UI: Press Resume
  UI -> Cubit: resume()
  Cubit -> Repo: resume(id, now)
  Cubit -> GPS: Resubscribe stream
  activate GPS
end

Cyclist -> UI: Press Finish
UI -> Cubit: finish()
Cubit -> GPS: Stop all streams
deactivate GPS

Cubit -> Repo: finish(id, now)
Repo -> Repo: Calculate summary
Repo -> DB: UPDATE ride_sessions\nstatus=completed
DB --> Repo: completed session
Repo --> Cubit: RideSessionSnapshot

Cubit -> Ledger: appendSession(session)
Ledger -> Ledger: Calculate hash chain
Ledger -> DB: Save proof block
Ledger --> Cubit: block appended

alt Auto-sync enabled & signed in
  Cubit -> Cubit: Upload summary to cloud
end

Cubit --> UI: Display ride summary

@enduml
```

---

### 5.3 Blockchain Proof Anchoring

```plantuml
@startuml
title Anchor Proof to Blockchain

actor Cyclist
participant "RideLedgerScreen" as UI
participant "RideLedgerCubit" as Cubit
participant "RideLedgerRepository" as Repo
participant "SupabaseRideLedgerSyncGateway" as Gateway
participant "sync-ride-proofs\nEdge Function" as SyncFn
participant "anchor-ride-proofs\nEdge Function" as AnchorFn
participant "PostgreSQL" as DB
participant "Relayer Wallet" as Relayer
participant "Sepolia RPC" as Chain

Cyclist -> UI: Open Ride Proofs
UI -> Cubit: load()
Cubit -> Repo: loadBlocks()
Repo --> Cubit: local blocks
Cubit -> Repo: verifyChain()
Repo -> Repo: Verify hash linkage
Repo --> Cubit: chain valid
Cubit --> UI: Display blocks

Cyclist -> UI: Press "Anchor to Blockchain"
UI -> Cubit: anchor()

Cubit -> Gateway: sync(blocks)
Gateway -> SyncFn: POST blocks + JWT
SyncFn -> DB: append_my_ride_proof_blocks()
DB --> SyncFn: block count + head hash
SyncFn --> Gateway: sync success
Gateway --> Cubit: synced

Cubit -> Gateway: anchor()
Gateway -> AnchorFn: POST action=anchor + JWT
AnchorFn -> DB: reserve_ride_proof_anchor()

alt Rate limit or duplicate
  DB --> AnchorFn: existing anchor
  AnchorFn --> Gateway: anchor list
  Gateway --> Cubit: existing anchor
  Cubit --> UI: Show existing anchor
else New anchor allowed
  DB --> AnchorFn: anchor_id, head, count
  AnchorFn -> AnchorFn: Build calldata:\nsenapath:v1:<count>:<head>
  AnchorFn -> Relayer: Sign transaction\n(0 ETH, calldata)
  Relayer -> Chain: eth_sendRawTransaction
  Chain --> Relayer: txHash
  Relayer --> AnchorFn: txHash
  
  AnchorFn -> DB: UPDATE anchor\nstatus=pending, txHash
  
  AnchorFn -> Chain: eth_getTransactionReceipt
  alt Receipt success
    Chain --> AnchorFn: receipt (status=1)
    AnchorFn -> DB: UPDATE anchor\nstatus=confirmed
  else Receipt failed
    Chain --> AnchorFn: receipt (status=0)
    AnchorFn -> DB: UPDATE anchor\nstatus=failed
  end
  
  AnchorFn --> Gateway: anchor list
  Gateway --> Cubit: anchors
  Cubit --> UI: Show anchor with txHash
end

Cyclist -> UI: Press "Open in Explorer"
UI -> UI: Open browser:\nsepolia.etherscan.io/tx/<txHash>

Cyclist -> UI: Press "Verify via RPC"
UI -> Cubit: verifyAnchor(anchor)
Cubit -> Chain: eth_getTransactionByHash(txHash)
Chain --> Cubit: transaction data
Cubit -> Chain: eth_getTransactionReceipt(txHash)
Chain --> Cubit: receipt

Cubit -> Cubit: Verify:\n- chainId matches\n- from = relayer address\n- calldata contains head hash\n- receipt status = success

alt All checks pass
  Cubit --> UI: Status: VERIFIED
else Mismatch
  Cubit --> UI: Status: MISMATCH
end

@enduml
```

---

### 5.4 Team Management

```plantuml
@startuml
title Join Team & Share Ride

actor Cyclist
participant "CyclingTeamScreen" as UI
participant "CyclingTeamCubit" as Cubit
participant "SupabaseCyclingTeamRepository" as Repo
participant "CustomAuthSessionManager" as Session
participant "PostgreSQL" as DB

Cyclist -> UI: Press "Join Team"
UI -> UI: Show invite code input
Cyclist -> UI: Enter 32-hex code
UI -> Cubit: joinTeam(inviteCode)

Cubit -> Repo: join(inviteCode)
Repo -> Session: requireAccessToken()
Session --> Repo: JWT

Repo -> DB: RPC join_cycling_team(code)
DB -> DB: Validate code format
DB -> DB: Check team exists
DB -> DB: INSERT cycling_team_members\nrole=member
DB --> Repo: team info + role
Repo --> Cubit: CyclingTeam

Cubit --> UI: Show team dashboard

== Sharing Ride ==

Cyclist -> UI: Select completed ride
Cyclist -> UI: Press "Share to Team"
UI -> Cubit: shareRide(teamId, sessionId)

Cubit -> Repo: shareRide(teamId, sessionId)
Repo -> DB: INSERT team_shared_ride_summaries
DB --> Repo: share record created
Repo --> Cubit: success

Cubit --> UI: "Ride shared to team"
UI -> UI: Show ride in team feed

note right of DB
  Team members can now see:
  - Ride date, distance, duration
  - Elevation gain
  - Activity type
  
  NOT shared:
  - GPS coordinates
  - Telemetry data
  - Personal info
end note

@enduml
```

---

### 5.5 AI Chat Assistant

```plantuml
@startuml
title AI Chat with Quota

actor Cyclist
participant "AiChatScreen" as UI
participant "AiChatCubit" as Cubit
participant "SupabaseAiChatGateway" as Gateway
participant "CustomAuthSessionManager" as Session
participant "rider-assistant\nEdge Function" as Assistant
participant "PostgreSQL" as DB
participant "Gemini API" as Gemini

Cyclist -> UI: Type question
UI -> Cubit: sendMessage(text)
Cubit -> Cubit: Add user message to state

Cubit -> Gateway: send(messages)
Gateway -> Session: requireAccessToken()
Session --> Gateway: JWT

Gateway -> Assistant: POST messages + JWT
Assistant -> Session: Verify JWT
Session --> Assistant: user_id

Assistant -> DB: consume_ai_chat_quota(user_id)
DB -> DB: Check daily limit (30/day)

alt Quota exhausted
  DB --> Assistant: false
  Assistant --> Gateway: HTTP 429
  Gateway --> Cubit: quota error
  Cubit --> UI: "Daily limit reached"
else Quota available
  DB --> Assistant: true
  Assistant -> Gemini: generateContent(messages)
  
  alt Gemini success
    Gemini --> Assistant: response text
    Assistant --> Gateway: response
    Gateway --> Cubit: message
    Cubit -> Cubit: Add assistant message
    Cubit --> UI: Display response
  else Gemini error
    Gemini --> Assistant: HTTP 4xx/5xx
    Assistant --> Gateway: error message
    Gateway --> Cubit: error
    Cubit --> UI: "AI service unavailable"
  end
end

@enduml
```

---

## How to Render

**VS Code:**  
Install "PlantUML" extension by jebbs, then open preview on any diagram block.

**JetBrains IDEs:**  
Install PlantUML plugin, right-click diagram block → "Show PlantUML Diagram".

**Online:**  
Copy diagram code to [PlantUML Server](http://www.plantuml.com/plantuml/uml/).

**CLI:**  
```bash
# Extract diagram to file.puml
java -jar plantuml.jar file.puml
```

---

## Architecture Notes

**Clean Architecture:**  
- **Presentation:** Cubit (BLoC pattern) manages UI state
- **Domain:** Models and repository interfaces (platform-agnostic)
- **Data:** Repository implementations, gateways, Drift database
- **Platform:** Native integrations (GPS, sensors, secure storage)

**Offline-First:**  
All core features work locally. Cloud sync is optional and explicit.

**Security:**  
- Telemetry encrypted with AES-256-GCM before storage
- Credentials use PBKDF2-SHA256 hashing
- Tokens stored in flutter_secure_storage
- Custom JWT verified by Edge Functions

**Blockchain Integration:**  
- Ethereum Sepolia testnet (no real value)
- Server-side relayer (user doesn't need wallet)
- Proof verification via public RPC (trustless)
- Only proof hashes on-chain, no personal data

---

Untuk dokumentasi naratif lengkap, lihat [CODEBASE.md](CODEBASE.md).
