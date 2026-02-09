# UI/UX Pro Level Design & Animation Overhaul

This document tracks the improvements to make PDFJimmy look and feel like a premium, top-tier application.

## Goals
- [ ] **Fluid Animations**: Use `flutter_animate` to bring static elements to life.
- [ ] **Glassmorphism**: Implement subtle glass effects for floating elements.
- [ ] **Interactive Feedback**: Ensure every tap has a satisfying response (scale, ripple, or sound).
- [ ] **Empty States**: Replace boring text with animated icons or illustrations.

## Implementation Plan

### 1. Project Setup
- [x] Add `flutter_animate` dependency.

### 2. Home Screen (`home_screen.dart`)
- [x] **Animated List**: Stagger in the "Recent Files" list items.
- [x] **Glass Tabs**: Redesign the TabBar to look like a floating glass capsule.
- [x] **Header**: Add a greeting with `AnimatedTextKit` or a subtle fade-in.
- [x] **Empty State**: Create a reusable, animated empty state widget.

### 3. Smart Scanner (`smart_scanner_screen.dart`)
- [x] **Scan Effect**: Add a pulsing or radar animation when waiting for scans.
- [x] **Hero Transitions**: Animate images from the list to the detail/edit view.
- [x] **Drag & Drop**: Polish the reorderable list interactions (haptic feedback).

### 4. Global Theming (`main.dart`)
- [x] **Transitions**: Set default page transition theme (e.g., `ZoomPageTransitionsBuilder`).
- [x] **Typography**: Verify font weights and line heights for a cleaner look.

### 5. Micro-Interactions
- [x] **Buttons**: Create a `ScaleButton` wrapper that shrinks slightly when pressed.
