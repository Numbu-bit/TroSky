# Changelog

## 0.1.0 - 2026-11-08

- Reference Smart Seat Allocation engine: passengers getting off farthest sit at the back,
  and those getting off nearest sit by the door. It covers batch and online allocation,
  general layouts (several rows, two doors, folding seats), priority and accessibility seats,
  groups, children with their adults, passenger swaps with a warning of the cost, locks,
  several pickups through seat-occupancy intervals (with chain exchanges between seats, so
  full vehicles are not stuck with what single moves can reach), and an audit log.
- It reports the blocking it could not avoid, why, and how that minimum was proven.
- Includes the layout schema and examples (all marked to verify against the fleet), a proposed
  database schema, a simulator, and unit, property-based and stateful tests. Standalone: the
  backend and apps do not use it yet.
