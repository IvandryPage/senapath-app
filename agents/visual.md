Senapath — Mobile App Design Direction
1. Product Character

Senapath is a cycling companion for cyclists who train and race.

Its core purpose is to help cyclists:

prepare routes and training sessions
record rides reliably
understand progress through transparent activity data
navigate during rides
review performance after rides

The visual identity should communicate:

serious cycling × cartoonist personality × tactile interface × technical clarity

Senapath should NOT look like:

a childish fitness app
a generic GPS/map application
a corporate SaaS dashboard
an overly polished glassmorphism app
an aggressive hardcore cycling computer

The desired feeling is:

Serious about cycling. Not serious-looking.

The app should feel like a well-designed cycling tool that happens to have a bold illustrated personality.

2. Overall Visual Direction

Use a cartoonist-inspired neobrutalist design language, but keep the information architecture serious and disciplined.

The interface should use:

bold typography
strong color blocking
thick dark borders
hard shadows
slightly oversized components
chunky buttons
expressive map markers
illustrated accents
simple geometric/cartoon shapes
high contrast
tactile interaction feedback

Avoid making every element loud.

The visual hierarchy should be:

DATA → ACTION → PERSONALITY

Data must remain the most trustworthy part of the interface.

Personality comes through:

colors
illustrations
shapes
motion
empty states
map markers
selected states
micro-interactions
3. Color Palette

Use the following brand palette.

Primary Colors
Coral

#FF6F61

Primary energetic brand color.

Use for:

primary highlights
important activity states
effort/intensity
selected visual accents
illustrations
Indigo

#4B0082

Deep purple used for:

secondary brand surfaces
training/planning states
strong visual sections
contrast against coral and yellow
Sky Blue

#00BFFF

Use primarily for:

navigation
route information
GPS/map-related UI
informational states
Gold

#FFD700

Use for:

achievements
personal bests
race-related emphasis
important highlights
reward states

Do not use Gold everywhere. It should feel special.

4. Supporting Colors
White

#FFFFFF

Primary surface color.

Use for:

cards
sheets
content areas
clean information blocks
Ink

#333333

Primary text and outline color.

Use instead of pure black in most situations.

It should be the main:

text color
border color
icon color
illustration outline
Pink

#FF4081

Expressive accent.

Use sparingly for:

special achievements
energetic states
illustrations
secondary highlights
Spring Green

#00FF7F

Performance/status accent.

Use for:

completed states
positive performance
active/completed ride states
healthy/positive metrics
Violet

#8A2BE2

Secondary purple accent.

Use for:

training
intensity
special categories
decorative illustration elements
5. Color Philosophy

Do NOT use all colors equally.

The UI should have a dominant neutral base with controlled bursts of color.

Recommended visual ratio:

45% White #FFFFFF
20% Ink #333333
15% Coral #FF6F61
7% Indigo #4B0082
5% Sky Blue #00BFFF
3% Gold #FFD700
2% remaining accent colors

The palette should feel colorful but intentional.

Never create a screen where every card has a different bright color.

Color should communicate meaning, not just decoration.

6. Semantic Color Mapping

Use colors consistently.

Navigation

#00BFFF

Primary action / energetic action

#FF6F61

Training / structured planning

#4B0082

Achievement / personal best

#FFD700

Completed / positive performance

#00FF7F

Special energetic accent

#FF4081

Secondary training accent

#8A2BE2

Text / borders

#333333

Surface

#FFFFFF

7. Neobrutalist Principles

Use neobrutalism carefully.

Borders

Use thick borders:

2px–4px solid #333333

Important components can use 4px borders.

Shadows

Use hard, offset shadows.

Example:

6px 6px 0px #333333

Do NOT use:

blur shadows
glass shadows
soft elevation
excessive gradients

The shadow should feel physical and tactile.

Border Radius

Do not make everything perfectly rounded.

Use a mixture:

8px
12px
16px
occasional sharp corners

Buttons and cards should feel slightly chunky.

8. Cartoonist Language

The cartoon character should come from the visual system rather than making the entire app look like a cartoon.

Use:

hand-drawn-inspired route markers
chunky icons
exaggerated arrows
expressive illustrations
irregular shapes
bold outlines
playful stickers
simple cyclist illustrations
slightly imperfect geometric forms

Do NOT use:

childish emoji-heavy UI
cute mascots everywhere
excessive facial expressions
cartoon backgrounds behind important data

The cyclist illustration should feel like an editorial sports illustration.

Think:

cycling magazine illustration + modern mobile UI

rather than:

children's game UI

9. Typography

Typography should be bold, compact, and athletic.

Use a strong grotesk/sans-serif for headings.

Possible fonts:

Space Grotesk
Sora
Archivo
Plus Jakarta Sans

For technical metrics, optionally use a monospace font:

IBM Plex Mono
Space Mono
JetBrains Mono

Example:

TEMPO RIDE

42.8 KM

+640 M

The heading should feel editorial and confident.

The numerical data should feel technical and trustworthy.

10. Data Visualization

Data visualization is a core part of Senapath.

Charts should be:

bold
simple
high contrast
easy to scan while riding or reviewing a ride

Avoid overly decorative charts.

Use thick strokes and strong colors.

Example:

Heart rate → Coral
Speed → Sky Blue
Elevation → Indigo
Completed segments → Spring Green
Personal best → Gold

Charts should feel like part of the Senapath brand, not generic analytics components.

11. Map Design

The map is one of the most important elements of the product.

Do not make the map visually compete with the route.

Use:

clean white background
restrained map details
strong route color
large readable markers
thick route strokes
expressive start/finish markers

Suggested route color:

#00BFFF

Start marker:

#00FF7F

Finish marker:

#FFD700

Current position:

#333333 with a white outline.

Important route segments can use:

#FF6F61

The map should feel like a cycling race map, not a generic Google Maps clone.

12. Buttons

Buttons should feel physical.

Primary button:

Coral background #FF6F61
Ink text #333333
3px Ink border
hard offset shadow
bold typography

Example:

START RIDE

When pressed:

move visually toward the shadow
reduce shadow offset
slightly scale down

This creates a tactile physical-button feeling.

Secondary buttons can use:

White
Indigo
Sky Blue
Gold

depending on semantic purpose.

13. Cards

Cards should look like physical pieces of paper or stickers placed on a cycling dashboard.

Example:

TEMPO RIDE

42.8 KM

+640 M

2h 04m

Use:

white or colored surface
3px Ink border
hard shadow
bold title
large metric
compact metadata

Do not add excessive decoration.

14. Home Screen

The home screen should prioritize the cyclist's next action.

Hierarchy:

Current / upcoming ride
Start Ride
Route
Training metrics
Recent progress

The screen should immediately answer:

What am I riding today?

and:

What should I do next?

Avoid generic motivational dashboard copy.

Prefer concise cycling language.

Examples:

TEMPO LOOP

42.8 KM · +640 M

READY TO RIDE

CONTINUE SESSION

LAST RIDE

+8% DISTANCE

15. Empty States

Empty states are an opportunity for the cartoonist personality.

Use simple cyclist illustrations and short copy.

Example:

NO RIDES YET

“Your first ride starts here.”

with a simple illustrated bicycle.

Avoid overly enthusiastic copy like:

“Let's get this adventure started!!! 🚀🎉”

The personality should be confident and understated.

16. Micro-interactions

Interactions should feel physical.

Examples:

buttons push down when tapped
cards slightly shift
route markers bounce minimally
achievement badges pop into place
charts animate from left to right
completed rides get a small celebratory movement

Animations should be fast and intentional.

Avoid excessive bouncing or playful animation.

The product is for cyclists, so interaction should feel fast and responsive.

17. Flutter Implementation Philosophy

Build the design system as reusable Flutter components.

Create reusable primitives such as:

SenapathCard
SenapathButton
SenapathMetric
SenapathChip
SenapathStat
SenapathChart
SenapathRoute
SenapathMapMarker
SenapathBadge

Create centralized design tokens for:

colors
typography
spacing
border widths
corner radius
shadows
animation duration

Do not hardcode visual values independently across screens.

The entire app should feel like one coherent visual system.

18. Final Design Principle

Senapath should feel like:

A cycling computer designed by an illustrator.

Not:

An illustration app pretending to be a cycling computer.

The app must always prioritize:

reliable recording → clear navigation → transparent data → personality

The visual personality should make Senapath memorable, while the information design makes it trustworthy.