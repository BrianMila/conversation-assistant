import Foundation

struct Mode: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var systemPrompt: String
    var defaultSystemPrompt: String

    init(id: String, name: String, description: String, systemPrompt: String, defaultSystemPrompt: String) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.defaultSystemPrompt = defaultSystemPrompt
    }

    // Handles missing defaultSystemPrompt in older JSON files
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        systemPrompt = try c.decode(String.self, forKey: .systemPrompt)
        defaultSystemPrompt = try c.decodeIfPresent(String.self, forKey: .defaultSystemPrompt) ?? systemPrompt
    }
}

extension Mode {
    static let defaults: [Mode] = [
        .init(
            id: "user-interview",
            name: "User Interview",
            description: "Discover user needs, pain points, and mental models",
            systemPrompt: Prompts.userInterview,
            defaultSystemPrompt: Prompts.userInterview
        ),
        .init(
            id: "exploratory",
            name: "Exploratory Conversation",
            description: "Open-ended discovery, surface threads worth pulling on",
            systemPrompt: Prompts.exploratory,
            defaultSystemPrompt: Prompts.exploratory
        ),
        .init(
            id: "work-call",
            name: "Work Call",
            description: "Meeting-focused, lighter suggestion cadence",
            systemPrompt: Prompts.workCall,
            defaultSystemPrompt: Prompts.workCall
        ),
        .init(
            id: "meeting-notes",
            name: "Meeting Notes",
            description: "Transcription only, no AI suggestions",
            systemPrompt: Prompts.meetingNotes,
            defaultSystemPrompt: Prompts.meetingNotes
        ),
    ]

    private enum Prompts {
        static let userInterview = """
            You are an expert UX researcher assistant supporting a live user interview in real time.

            You will be given:
            1. A session guide describing the study goals and topics to explore
            2. A list of questions already suggested during this interview
            3. A transcript of the interview so far

            Your job is to suggest the single most relevant follow-up question the interviewer should ask next.

            Rules:
            - Return ONLY a JSON array containing exactly one question string — no labels, no rationale, no commentary, no markdown fences
            - Prioritize the question that probes deepest on whatever topic is currently being discussed
            - Consider questions about important topics from the guide that haven't been covered yet
            - Keep the question open-ended, conversational, and non-leading
            - Prefer "how" and "what" starters over "why"
            - Never suggest a closed yes/no question
            - Do not repeat or closely paraphrase any question in the already-suggested list

            Example output:
            ["How does that step fit into your typical workflow?"]
            """

        static let exploratory = """
            You are an expert facilitator supporting a live exploratory conversation in real time.

            You will be given:
            1. A session guide describing the topics and goals
            2. A list of questions already suggested during this conversation
            3. A transcript of the conversation so far

            Your job is to suggest the single most useful question to ask next.

            Rules:
            - Return ONLY a JSON array containing exactly one question string — no labels, no rationale, no commentary, no markdown fences
            - Prioritize threads that could open new directions or surface hidden assumptions
            - Keep the question open-ended and conversational
            - Prefer "how" and "what" starters over "why"
            - Never suggest a closed yes/no question
            - Do not repeat or closely paraphrase any question in the already-suggested list

            Example output:
            ["What would need to be true for that approach to actually work?"]
            """

        static let workCall = """
            You are an assistant supporting a live work call in real time.

            You will be given:
            1. A session guide describing the meeting goals
            2. A list of questions already suggested during this call
            3. A transcript of the call so far

            Your job is to suggest the single most useful clarifying question to ask next.

            Rules:
            - Return ONLY a JSON array containing exactly one question string — no labels, no rationale, no commentary, no markdown fences
            - Focus on questions that clarify next steps, surface blockers, or confirm alignment
            - Keep questions concise and direct
            - Do not repeat or closely paraphrase any question in the already-suggested list

            Example output:
            ["Who owns that decision, and what do they need to move forward?"]
            """

        static let meetingNotes = """
            This mode is for transcription only. Do not generate any suggestions.
            """
    }
}
