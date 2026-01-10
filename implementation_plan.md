# implementation_plan.md

## Project: Privacy-First Shared Trip Discovery App

### Objective

Build a mobile app that proactively discovers shared trips between users by locally clustering photos, matching anonymous event fingerprints via a backend, and allowing explicit sharing.

### Phase 1: Core Logic & Data Modeling (The "First Step")

**Goal**: Implement the logic to group local photos into "Events" based on time and location without leaving the device.

- [ ] **Define Data Models**: `PhotoMetadata` (timestamp, lat/lon), `Cluster/Event` (centroid, time range).
- [ ] **Implement Clustering Algorithm**: Create a service that takes a stream of photo metadata and outputs clusters.
  - _Heuristic_: Photos within X meters and Y hours of each other belong to the same event.
- [ ] **Generate Fingerprints**: Create a hashed/anonymous representation of an event (e.g., localized geo-hash + quantized time buckets) for privacy-preserving matching.

### Phase 2: Backend & Matching

**Goal**: A lightweight API to check for overlapping fingerprints.

- [ ] **API Definition**: `findOverlaps(fingerprints: [String]) -> [MatchedEventID]`.
- [ ] **Backend Service**: Simple server (Swifter/Vapor or Node) to check overlapping hashes.
- [ ] **Privacy**: Ensure user IDs are not stored permanently with locations; only ephemeral matching.

### Phase 3: iOS Application & Photo Library Integration

**Goal**: interacting with the user's real data.

- [ ] **PhotoKit Integration**: Request permissions and fetch metadata from the user's Camera Roll.
- [ ] **Local Processing**: Run Phase 1 logic on the fetched data.
- [ ] **UI/UX**:
  - "Scan Photos" button.
  - List of "Found Events".
  - Detail view to see photos in an event.

### Phase 4: Sharing & Syncing

- [ ] **P2P / Cloud Handshake**: Once an overlap is found, facilitate a secure key exchange to share specific photo assets.
- [ ] **Shared Album UI**: View shared photos.

## Immediate Next Step

**Implement Phase 1: Core Clustering Logic.**

1. Create `Models.swift`: Structs for `Photo`, `Location`, `Event`.
2. Create `ClusteringService.swift`: Logic to group photos.

Since you are deploying to an iPhone, you must ensure your project's Info.plist includes the Privacy - Photo Library Usage Description key (NSPhotoLibraryUsageDescription). Without this, the app will crash immediately when it tries to request photo permissions.

If you are opening this Swift Package directly in Xcode:

Click on the "app" target in the project settings.
Go to the Info tab.
Add a generic Key NSPhotoLibraryUsageDescription (or select "Privacy - Photo Library Usage Description" from the dropdown).
Set the Value to something like: "We need access to your photos to import them into the album."
