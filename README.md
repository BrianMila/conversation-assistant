# Conversation Assistant

A real-time conversation assistant for iOS. It listens to a live conversation and surfaces
suggested questions and follow-ups on the fly — built for user-research interviews, but useful
for any conversation where you give it context up front (the topic, and what you're trying to
learn or ask).

## What it does
- Listens to a conversation in real time
- Uses the context you provide — your goals and the questions you want answered — to suggest
  relevant questions and follow-ups as the conversation unfolds
- Powered by the Anthropic API (Claude). Your API key is stored securely in the iOS Keychain
  and is only ever sent to Anthropic to make the API call

## Stack
- SwiftUI (iOS)
- Anthropic API (Claude) for suggestion generation
- Keychain for secure on-device API-key storage

## Setup
1. Open the project in Xcode and run on an iOS device or simulator.
2. In the app, paste your Anthropic API key (it's saved to the Keychain).
3. Give the assistant context for the conversation — the topic and what you want to ask or
   learn — then start listening.
