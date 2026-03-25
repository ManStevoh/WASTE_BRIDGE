---
title: Architecture
layout: default
nav_order: 4
---

# System Architecture

## Core Layers

- Laravel API
- Flutter App
- Realtime Services
- Payments & Wallet

---

## Flow

1. Request → API  
2. API → Database  
3. Events → Realtime  
4. Payment → Wallet  

---

## Scaling Strategy

- Stateless APIs
- Queue workers
- Redis caching
- Multi-tenant design
