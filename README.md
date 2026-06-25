# Callsy

![React](https://img.shields.io/badge/React-Frontend-61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript-Full%20Stack-3178C6)
![Express](https://img.shields.io/badge/Express-Backend-000000)
![MongoDB](https://img.shields.io/badge/MongoDB-Database-47A248)
![Twilio](https://img.shields.io/badge/Twilio-Voice%20%26%20SMS-F22F46)
![OpenAI](https://img.shields.io/badge/OpenAI-AI-412991)
![License](https://img.shields.io/badge/License-MIT-blue)

An AI-powered customer follow-up platform designed to help businesses recover missed opportunities by automatically engaging callers through intelligent SMS conversations and personalized follow-up messaging.

# Overview

Callsy was developed as an independent startup project to address a common business problem: missed phone calls often result in lost customers.

The platform automatically detects missed calls, initiates personalized SMS conversations, classifies incoming responses using AI, and helps businesses identify qualified leads without requiring immediate staff intervention.

Rather than functioning as a simple messaging platform, Callsy combines conversational AI, automated workflows, and customer relationship management into a unified follow-up system capable of responding intelligently to customer interactions.

Although development is currently paused, the project demonstrates the architecture and core functionality required for an AI-assisted customer engagement platform.

# Features

## Business Accounts

- Business registration
- Secure authentication
- Account management
- Business profile configuration

## AI-Powered Follow-Up

- Automatic missed-call follow-up
- AI-generated personalized responses
- Business-aware message generation
- Configurable conversation tone
- Booking link integration

## Lead Qualification

- AI-powered lead classification
- Spam detection
- Wrong-number identification
- Existing customer recognition
- Qualified lead detection
- Confidence scoring

## SMS Automation

- Twilio SMS integration
- Automated follow-up messaging
- Incoming message processing
- Conversation history
- Response tracking

## Lead Management

- Customer lead database
- Call history
- SMS history
- Lead status tracking
- Business-specific lead organization

## Administration

- Health monitoring endpoints
- Authentication middleware
- Logging
- Error handling
- Environment-based configuration

# Technology Stack

## Frontend

- React
- TypeScript
- Vite
- React Router

## Backend

- Node.js
- Express
- TypeScript
- JWT Authentication

## Database

- MongoDB

## AI

- OpenAI API
- GPT-powered message generation
- AI lead classification

## Communication

- Twilio Voice
- Twilio SMS

# Architecture

Callsy follows a service-oriented client-server architecture integrating conversational AI with telephony services.

                    React Frontend
                           │
                     REST API Requests
                           │
                           ▼
                  Express / TypeScript API
                           │
      ┌──────────────┬───────────────┬──────────────┐
      │              │               │              │
      ▼              ▼               ▼              ▼
   MongoDB       OpenAI API      Twilio SMS     Twilio Voice
      │              │               │              │
      └──────────────┴───────────────┴──────────────┘
                           │
                           ▼
                  Business Follow-up Pipeline

Incoming customer interactions are processed through backend services responsible for authentication, lead management, AI-assisted response generation, message classification, and Twilio communication.


# AI Workflow

Missed Call
      │
      ▼
Generate Personalized SMS
      │
      ▼
Customer Replies
      │
      ▼
AI Classifies Response

Lead
Existing Customer
Wrong Number
Spam
Unknown

      │
      ▼
Business Dashboard

This workflow allows businesses to automatically engage customers while filtering low-value interactions and identifying qualified leads.

# Security

The platform was designed with separation between business logic and external services.

Security features include:

- JWT authentication
- Environment-based secret management
- Password hashing
- Protected API routes
- Input validation
- Twilio request validation

# Challenges

Key engineering challenges included:

- Integrating AI-generated responses into deterministic workflows
- Designing reliable lead-classification pipelines
- Coordinating OpenAI and Twilio APIs
- Managing asynchronous SMS conversations
- Building reusable backend service architecture
- Separating AI logic from business logic
- Designing scalable conversation workflows

# Future Improvements

Potential future enhancements include:

- Multi-user business organizations
- Appointment scheduling integration
- CRM integrations
- Analytics dashboard
- Voice AI call handling
- Fine-tuned lead classification models
- Conversation memory
- Multi-language support
- Production deployment

# Project Status

Development is currently on hiatus while I pursue personal research in AI architecture.

The project demonstrates the architecture and implementation of an AI-assisted customer engagement platform integrating conversational AI, telephony APIs, automated lead qualification, and modern full-stack web development.
