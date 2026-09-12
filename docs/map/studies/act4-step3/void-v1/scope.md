## CI check selection

Mode: **scope-aware changed-path gate**. Changed paths: **44**; changed GDScript files parsed: **12**.

### Scopes

| Scope | Decision | Reason |
| --- | --- | --- |
| `godot_code` | **SELECTED** | 33 changed path(s) matched |
| `map_code` | **SELECTED** | 1 changed path(s) matched |
| `map_assets` | **SKIPPED** | no changed path matched |
| `balance_ml` | **SKIPPED** | no changed path matched |
| `provenance_evidence` | **SKIPPED** | no changed path matched |
| `locale_content` | **SKIPPED** | no changed path matched |
| `agent_config` | **SKIPPED** | no changed path matched |
| `docs` | **SELECTED** | 3 changed path(s) matched |
| `release_platform` | **SKIPPED** | no changed path matched |
| `presentation` | **SELECTED** | 5 changed path(s) matched |
| `dev_tools` | **SKIPPED** | no changed path matched |
| `ci_infra` | **SKIPPED** | no changed path matched |
| `conservative_core` | **SELECTED** | 8 changed path(s) matched |

### Checks

| Check | Decision | Reason |
| --- | --- | --- |
| Test CI scope classifier | **SELECTED** | selection authority is tested on every run |
| Check AI-SDLC agent contracts | **SKIPPED** | none of the relevant scopes selected: agent_config |
| Setup Godot | **SELECTED** | selected scope(s): godot_code, map_code, presentation, conservative_core |
| Import assets | **SELECTED** | selected scope(s): godot_code, map_code, presentation, conservative_core |
| Test asset import gate failures | **SKIPPED** | none of the relevant scopes selected: ci_infra |
| Check GDScript syntax | **SELECTED** | 12 changed GDScript file(s) remain at the PR head |
| Test GDScript gate failures | **SKIPPED** | none of the relevant scopes selected: ci_infra |
| Check zh-Hant bundled font coverage | **SKIPPED** | none of the relevant scopes selected: locale_content |
| Check narrative locale coverage | **SKIPPED** | none of the relevant scopes selected: locale_content |
| Check store Dev-tree exclusion | **SKIPPED** | none of the relevant scopes selected: release_platform |
| Test store Dev-tree exclusion gate | **SKIPPED** | none of the relevant scopes selected: release_platform |
| Check developer-tool registry and coordinate conversion | **SKIPPED** | none of the relevant scopes selected: dev_tools |
| Test balanced content DOE generator | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test content-search seed contract | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test s009 exam catalogue reconstruction | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test Tier-1 grouped breadth registry | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test candidate loading and host-qualify fail-closed | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test F0 evaluator protocol | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test Tier-1 F0 response contract | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test F1/F2 racing and model adequacy rules | **SKIPPED** | none of the relevant scopes selected: balance_ml |
| Test execution-provenance capability | **SKIPPED** | none of the relevant scopes selected: provenance_evidence |
| Check doc file:line anchors | **SELECTED** | selected scope(s): docs |
| Check no new web-reference citations | **SELECTED** | selected scope(s): docs |
| Check map tile and module assets | **SKIPPED** | none of the relevant scopes selected: map_assets |
| Check Map Compiler v2 quality contract | **SELECTED** | selected scope(s): map_code |
| Test performance evidence replay | **SELECTED** | selected scope(s): presentation |
| Run tests | **SELECTED** | selected scope(s): godot_code, conservative_core |
| Probe shared map asset profiles | **SELECTED** | selected scope(s): map_code |
| Test phone-landscape scroll reachability | **SELECTED** | selected scope(s): presentation |
| Test boss-relic phone containment | **SELECTED** | selected scope(s): presentation |
| Test Dawn phone containment | **SELECTED** | selected scope(s): presentation |
| Test run HUD location fit | **SELECTED** | selected scope(s): presentation |

<details><summary>Classified changed paths</summary>

<ul>
<li><code>PLAN.md</code></li>
<li><code>docs/art-ledger.md</code></li>
<li><code>docs/map/studies/act4-step3/void-v1/sample-717.json</code></li>
<li><code>presentation/combat/combat_screen.gd</code></li>
<li><code>presentation/stage/mirrored_finish.gd</code></li>
<li><code>presentation/stage/mirrored_finish.gd.uid</code></li>
<li><code>presentation/stage/mirrored_ground.gdshader</code></li>
<li><code>presentation/stage/mirrored_ground.gdshader.uid</code></li>
<li><code>tools/map_workshop/act4/audit.gd</code></li>
<li><code>tools/map_workshop/act4/audit.gd.uid</code></li>
<li><code>tools/map_workshop/act4/build_kit.py</code></li>
<li><code>tools/map_workshop/act4/combat_study.gd</code></li>
<li><code>tools/map_workshop/act4/combat_study.gd.uid</code></li>
<li><code>tools/map_workshop/act4/echoes.gd</code></li>
<li><code>tools/map_workshop/act4/echoes.gd.uid</code></li>
<li><code>tools/map_workshop/act4/embers.gd</code></li>
<li><code>tools/map_workshop/act4/embers.gd.uid</code></li>
<li><code>tools/map_workshop/act4/embers.gdshader</code></li>
<li><code>tools/map_workshop/act4/embers.gdshader.uid</code></li>
<li><code>tools/map_workshop/act4/inspection.gd</code></li>
<li><code>tools/map_workshop/act4/inspection.gd.uid</code></li>
<li><code>tools/map_workshop/act4/kit/memory-stele.glb</code></li>
<li><code>tools/map_workshop/act4/kit/memory-stele.glb.import</code></li>
<li><code>tools/map_workshop/act4/kit/other-side-hearth.glb</code></li>
<li><code>tools/map_workshop/act4/kit/other-side-hearth.glb.import</code></li>
<li><code>tools/map_workshop/act4/kit/threshold-window.glb</code></li>
<li><code>tools/map_workshop/act4/kit/threshold-window.glb.import</code></li>
<li><code>tools/map_workshop/act4/kit_finish.gdshader</code></li>
<li><code>tools/map_workshop/act4/kit_finish.gdshader.uid</code></li>
<li><code>tools/map_workshop/act4/processional_stone.gdshader</code></li>
<li><code>tools/map_workshop/act4/processional_stone.gdshader.uid</code></li>
<li><code>tools/map_workshop/act4/profile.gd</code></li>
<li><code>tools/map_workshop/act4/profile.gd.uid</code></li>
<li><code>tools/map_workshop/act4/spatial-recipe.json</code></li>
<li><code>tools/map_workshop/act4/study.gd</code></li>
<li><code>tools/map_workshop/act4/study.gd.uid</code></li>
<li><code>tools/map_workshop/act4/tour.gd</code></li>
<li><code>tools/map_workshop/act4/tour.gd.uid</code></li>
<li><code>tools/map_workshop/act4/verify_combat_material.gd</code></li>
<li><code>tools/map_workshop/act4/verify_combat_material.gd.uid</code></li>
<li><code>tools/map_workshop/act4/verify_source.gd</code></li>
<li><code>tools/map_workshop/act4/verify_source.gd.uid</code></li>
<li><code>tools/map_workshop/act4/void_background.gdshader</code></li>
<li><code>tools/map_workshop/act4/void_background.gdshader.uid</code></li>
</ul>

</details>
