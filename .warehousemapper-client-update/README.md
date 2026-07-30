# WarehouseMapper iOS Scanner

This is the first local-only sensor prototype. It does not use a backend, API key, cloud service, or paid dependency.

## What it proves

- The iPhone can create a live gray scene mesh from LiDAR.
- ARKit can report the phone's movement through the scene.
- Tracking quality, scan guidance, and thermal warnings can be shown to the person performing the scan.
- The mesh and movement path can be saved locally.
- A saved scan can be reopened as a first-person walkthrough or interactive 3D model.
- A clean rectangular zone shell, orientation grid, start marker, and minimap can be generated from the scan.
- Named warehouse zones can be sized, rotated, and positioned on a local 3D planning board.
- Existing scans can be attached to zones, and rescanning a zone creates a reversible revision instead of destroying the previous scan.
- Zone dimensions can be entered directly in feet or meters, with an explanation beside every measurement.
- The app generates numbered, high-contrast location markers that can be printed on ordinary paper or cardstock.
- Marker setup gives the operator one instruction at a time and establishes a repeatable physical coordinate frame for later updates.
- Saved scans can be exported, assigned to a zone, or reassigned without rescanning.
- QR codes, UPC/EAN labels, Code 39/93/128, Data Matrix, PDF417, and Aztec codes are detected locally during scanning and stored at their estimated 3D locations.
- Captured codes appear as green pins in the saved model and can be searched, copied, or exported with X/Y/Z coordinates as CSV.
- Tapping a green pin opens an editable local item record with a product name, SKU/reference, and notes.
- Searching by product, SKU, note, or raw code and tapping a result focuses the 3D camera on that location and draws a green line from the scan start.
- Saved-scan layer controls can independently hide walls, floors, and ceilings, including a one-tap **Stuff only** preset.
- The live LiDAR overlay is rendered as translucent wireframe so it shows coverage without covering the camera view of a floor, rack, object, or barcode.

## Requirements

- A Mac with Xcode
- An iPhone or iPad with LiDAR
- An Apple Account signed into Xcode
- A cable for the first device connection

The iOS Simulator can compile and display the interface, but it cannot provide a real camera, ARKit world tracking, or LiDAR mesh. The sensor test must run on the physical iPhone.

## Run on the iPhone

1. Open `WarehouseMapperScanner.xcodeproj` in Xcode.
2. Connect the iPhone to the Mac and unlock it.
3. Approve **Trust This Computer** if the iPhone asks.
4. In Xcode, open **Xcode → Settings → Accounts** and add your Apple Account.
5. Click the blue **WarehouseMapperScanner** project in the left sidebar.
6. Select the **WarehouseMapperScanner** target, then **Signing & Capabilities**.
7. Turn on **Automatically manage signing** and select your Personal Team.
8. At the top of Xcode, choose your physical iPhone as the run destination.
9. Press the triangular **Run** button.
10. If iOS asks for Developer Mode, open **Settings → Privacy & Security → Developer Mode**, enable it, restart the iPhone, and run again.
11. On first launch, allow camera access.

With a free Personal Team, the installed development build normally needs to be rebuilt after its provisioning profile expires.

After the first wired installation, the scanner itself runs entirely on the iPhone. Disconnect the cable and launch it from the Home Screen; neither Xcode nor the Mac is required while scanning. Xcode's wireless device connection is only needed when installing another development build or reading live debug logs.

## Perform the first test

1. Begin in a small, well-lit room rather than the warehouse.
2. Press **How to scan** and review the guided zone workflow.
3. Start at an entrance or another repeatable reference point, then press **Start Scan**.
4. Move slowly with overlap. Show the floor, walls, rack faces, corners, labels, and objects with visible detail.
5. Watch the live guidance:
   - **Tracking good** means ARKit has a stable pose.
   - **Move slower** means camera motion is too fast.
   - **Needs visual detail** means the camera sees surfaces that are too blank or repetitive.
   - A heat warning means finish the current section and let the phone cool before continuing.
6. Confirm differently shaded gray surfaces appear over the camera image.
7. Confirm orange dots appear along the route you walked.
8. Press **Stop & Save** after approximately 30–90 seconds. Prefer several short named zones over one enormous scan.
9. Press **Saved** and open the latest scan.
10. Use **Walkthrough** to replay the phone's point of view, the minimap to stay oriented, and **Model** to orbit the complete scan.
11. Adjust **Raw scan** opacity to compare the captured mesh with the clean floor, grid, and zone boundary.

## Build the warehouse map

1. Press **Map** on the scanner screen.
2. Rename **My Warehouse** if desired.
3. Press **Zone**, choose feet or meters, and type the zone's width, length, and height. Each field explains which physical direction to measure.
4. Enter the map rotation only when the aisle is angled relative to the planning board.
5. Review the recommended marker count, paper size, maximum gap, and mounting height.
6. Press **Share markers**, share or save the PDF, and print at **Actual Size / 100%** on ordinary matte paper or cardstock. No specialized marker hardware is required.
7. Mount **Entrance / Marker 1** at the zone entrance and place the remaining numbered markers in order around the zone. Keep every marker flat, fully visible, and at the recommended height.
8. Press **Set up markers**. Point the camera at the marker named on screen; the app advances from Entrance to Marker 2 and continues until all markers are recorded.
9. When the app says the zone is ready, press **Scan Zone** and scan normally. The completed scan becomes revision 1 for that persistent zone.
10. Drag the zone on the 3D board to place it; pinch to zoom. Repeat for each independently maintainable area.
11. For a changed area, press **Update scan**. The app first uses Entrance and one additional marker to return to the zone's saved coordinate frame, then creates a new active revision while retaining the older scan under **Scan history**.
12. Use **Make current** to roll back, or **Attach saved** to connect an earlier scan.

The marker workflow now aligns separate sessions to the same zone and saves ARKit's relocalization map with each revision. The current update still replaces the complete active geometry for that zone; geometrically merging only a small partial patch is a later milestone. Keeping zones compact prevents a changed aisle from forcing a rescan of the entire warehouse.

### Test markers without a printer

For a short recognition test, open different pages of the marker PDF full-screen on fixed laptops, tablets, or spare phones. Use high brightness, disable screen sleep, keep the displays still, and avoid glare. This proves the detection flow, but it is not a permanent warehouse installation because the screens must stay in exactly the same locations for future updates.

You can also create and scan a zone without completing marker setup. The mesh and barcode capture work normally, but a later scan cannot reliably return to the same physical coordinate frame until permanent markers are installed.

## Capture QR codes and barcodes

1. Begin a normal zone scan.
2. Move near a bin or pallet label and hold the code sharp and near the center of the camera for a moment.
3. A green ring and **Captured** message confirm the value and its 3D location.
4. Repeated sightings within the same physical area increase the confirmation count instead of creating duplicate locations. The same code detected farther away can create another location.
5. Stop and save the scan, open **Saved**, and select the scan.
6. Green numbered pins show code locations in the saved model. Tap a pin to name the item, add its SKU/reference and notes, or focus its location.
7. Press **Open captured codes** to search by product name, SKU, note, or raw code. Tapping a result switches to the model, focuses the camera on its pin, and draws a green line from the scan start.
8. Export the enriched list, including product details and X/Y/Z coordinates, as CSV.

Recognition runs on the iPhone through Apple's Vision framework at a throttled interval. It needs no API key, cloud service, or per-scan fee. A LiDAR surface hit is used when available; otherwise the app saves a clearly labeled camera-distance estimate that should be confirmed on another pass.

## See through building surfaces

Open a saved scan and press **Visible layers**:

- Turn off **Walls**, **Floor**, or **Ceiling** independently.
- Choose **Stuff only** to hide all three building-surface classifications.
- Choose **Reset layers** to restore walls and floor.

ARKit classifications are useful but imperfect: a large rack face can occasionally be classified as a wall, while some wall geometry can remain **Unknown**. The individual toggles and raw-detail opacity slider let the operator choose the clearest view rather than permanently deleting geometry.

## Manage and export saved scans

1. Press **Saved**.
2. Use the row menu or swipe actions to **Assign** an unassigned scan or **Reassign** it to a different zone.
3. Press **Export** to share the raw `.warehouse-scan` archive through Files, AirDrop, or another installed destination.
4. An open saved scan also has a share button in its toolbar.

Export preserves the raw mesh, camera path, zone association, and saved ARKit world map. It is a data archive for WarehouseMapper, not a standard CAD model yet.

Only move to a warehouse aisle after this test saves and reopens correctly.

## Source layout

### `WarehouseMapperScannerApp.swift`

The application entry point. It creates one `ScanSessionController` and shares that controller with the SwiftUI interface.

### `ContentView.swift`

The visible scanner interface. It overlays scan status, mesh count, path distance, elapsed zone time, tracking/thermal guidance, instructions, and controls on top of the live camera.

### `Scanner/ScanSessionController.swift`

The state and workflow coordinator. It:

- Starts and pauses the `ARSession`
- Enables LiDAR scene reconstruction
- Chooses a lower-power 30 FPS capture format when the device offers one
- Samples the phone pose about ten times per second
- Calculates approximate traveled distance
- Draws the orange movement trail
- Produces motion, coverage, duration, and thermal guidance
- Collects the current mesh when scanning stops
- Creates and saves the local archive

### `Scanner/ARScannerView.swift`

The bridge between SwiftUI and Apple's `ARSCNView`. SwiftUI cannot directly display an ARKit session, so this wrapper creates the native AR view and receives ARKit frame and mesh updates. It includes Apple's tracking-coaching overlay and throttles expensive live mesh rebuilding to reduce heat and battery use.

### `Scanner/ARMeshGeometry+SceneKit.swift`

Converts ARKit's Metal mesh buffers into SceneKit geometry. It groups ARKit surface classifications into a restrained industrial-gray palette, preserves mesh normals for new archives, and calculates averaged normals when opening older scans to make their lighting less blocky.

### `Storage/ScanArchive.swift`

Defines the versioned saved data contract:

- Full camera transforms over time
- Mesh vertices, normals, triangle indices, semantic classifications, and anchor transforms
- Start and end dates
- Device and system information
- Approximate path distance
- The assigned zone identifier and ARKit world map used for marker-assisted updates
- Detected barcode payloads, types, confirmation counts, and 3D positions

New `.warehouse-scan` files use a compact binary property-list archive in the application's Documents directory. The loader remains backward compatible with the original JSON scans.

### `Storage/WarehouseMap.swift`

Stores the local warehouse plan, measurement-unit preference, named zone dimensions and placement, generated marker identities and transforms, scan-to-zone links, active revisions, and previous scan history. The plan is saved independently from scan geometry so a rescan never destroys the zone's identity or map position.

### `Planner/WarehouseMapView.swift`

The client-side planning workflow. It creates and edits zones in feet or meters, explains every measurement, generates printable numbered markers, starts guided marker setup, assigns earlier scans, and provides revision history and rollback.

### `Planner/MarkerKit.swift`

Generates the high-contrast numbered marker artwork, runtime ARKit reference images, and printable Letter-size PDF pack. It also provides the normal iOS share sheet used for marker PDFs and raw scan exports.

### `Planner/WarehouseMapSceneView.swift`

The interactive SceneKit planning board. It draws approximate zone footprints and equipment/rack representations, visualizes recommended marker positions, and supports selection, drag placement, and pinch zoom.

### `Review/SavedScansView.swift`

Lists locally saved scans, shows their zone assignment, assigns or reassigns them, exports raw archives, and loads the selected archive.

### `Review/SavedScanView.swift`

Reconstructs the saved mesh in SceneKit and provides:

- A first-person replay of the recorded phone poses
- A top-right orientation minimap with start and current-position markers
- An orbit/zoom model view
- A clean rectangular zone shell with floor grid and start marker
- A raw-mesh opacity control for comparing captured and clean geometry

## Important limitations

- Printed-marker recognition and physical placement must still be field-tested in the actual warehouse. Lighting, glare, print scaling, obstructions, and markers that move after setup can reduce recognition quality.
- Barcode capture records the value printed in the code. Product names, SKU/reference values, and notes can be added locally, but quantity and ERP inventory records still require an inventory import or integration.
- A 3D barcode position from a LiDAR surface is an operational location estimate, not survey-grade measurement. Camera-only fallback positions are explicitly labeled **Estimated**.
- **Show location in model** is visual navigation inside the saved 3D scan. Turn-by-turn physical AR navigation requires the phone to relocalize inside the zone and is a separate milestone.
- The clean zone shell is a padded rectangle based on scan bounds; it does not yet detect or fit rack templates.
- A zone update is a safe full-zone replacement revision, not a geometrically merged partial patch.
- Long scans are still held in memory until **Stop & Save**. Production scanning needs incremental zone checkpoints.
- Scans remain inside the app sandbox unless exported and are deleted if the app is uninstalled.
- Distance is an approximation based on sampled camera movement, not a certified measurement.

The next milestone is field-validating marker recognition and then merging an aligned partial mesh patch into an existing revision. Rack-template fitting and incremental on-disk checkpoints follow that.

## Troubleshooting

### Signing error

Select the project target in Xcode, open **Signing & Capabilities**, and choose your Apple Account under **Team**. If the bundle identifier is already taken, replace `com.paulclarkiv.WarehouseMapperScanner` with another unique value.

### Developer Mode is unavailable

Connect the iPhone to Xcode once and attempt to run the application. iOS should then expose or request Developer Mode.

### No gray mesh

Verify that the selected device is the iPhone 16 Pro Max rather than the simulator. Use a well-lit area and move the phone slowly while viewing nearby surfaces.

### Tracking says it needs visual detail

Blank walls, glossy floors, darkness, repeated shelving, and motion blur reduce visual tracking quality. Aim toward corners, labels, rack edges, and textured objects while moving slowly.

### Saved file is unexpectedly large

The binary archive is smaller than the original JSON format, but it still contains full mesh geometry. Scan and save one zone at a time instead of mapping an entire warehouse in one session.
