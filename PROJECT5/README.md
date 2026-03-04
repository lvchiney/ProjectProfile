# Enterprise AI Governance Dashboard
**Azure AI · Production Observability · Responsible AI · Policy-as-Code**

---

## Why I built this

I've spent 16 years watching enterprise systems fail in the same way: they work on demo day, then silently degrade in production with no one watching.

AI models have the same problem — but with higher stakes. A document classifier trained on last year's data drifts. A speech pipeline leaks a PII entity. A GPT-4o deployment starts hallucinating because the knowledge base wasn't refreshed. Without governance infrastructure, nobody knows until a client complains.

This project is my answer to that problem. Not another chatbot. A governance layer for AI systems already in production.

---

## What it does

A single-pane-of-glass dashboard for every Azure AI deployment in an enterprise — showing evaluation scores, incidents, policy compliance, and cost, continuously.

**Four views:**

**Overview** — health matrix across all deployed models: groundedness, coherence, fluency, relevance, latency, request volume, drift flags. A principal engineer or AI delivery lead can see exactly what needs attention.

**Models** — drill into any deployment. See evaluation scores from the Azure AI Evaluation SDK, whether RAG grounding and content safety are active, which labs power it, and operational metrics (p95 latency, 30-day spend).

**Incidents** — structured log of AI-specific production events: metric drift, PII leaks, latency SLA breaches, tool timeouts. Each incident includes what happened, why, and what was done. Full audit trail.

**Policy Engine** — codified rules that govern every model. Groundedness below 80%? Auto-alert and block deployment. Toxicity above 1%? Route to human review. PII in output? Immediate incident and patch. Policy-as-code, not verbal agreements.

---

## Architecture decisions (and why I made them)

**Why governance, not another feature demo?**
Any engineer with a weekend can build a chatbot. What separates a senior AI engineer is knowing that the chatbot is 10% of the work. Deployment, monitoring, drift detection, responsible AI enforcement, and cost governance are the other 90%. This project demonstrates that I think at that level.

**Why continuous evaluation (LAB 5) as a first-class component?**
In traditional software, you test before you deploy. In AI, you test *continuously* — because model behaviour changes as the world changes, even if the weights don't. I built the evaluation harness as a scheduled job, not a one-time script, because that's what production requires.

**Why policy-as-code (LAB 4)?**
I've seen "responsible AI" implemented as a slide deck and a verbal agreement. It doesn't survive team turnover or audit. Codified rules with automated enforcement — groundedness thresholds, PII tolerance, toxicity gates — are auditable, transferable, and actually enforced.

**Why RAG over fine-tuning (LAB 3)?**
For enterprise knowledge that changes (policies, procedures, vendor data), RAG is the right architectural choice. Fine-tuning bakes knowledge into weights — expensive, slow to update, impossible to audit. RAG keeps knowledge in a retrieval index — updatable, citeable, auditable. I chose it deliberately.

**Why Semantic Kernel (LAB 10) over direct API calls?**
After 16 years, I know that code written for a demo becomes the code maintained for years. Semantic Kernel gives agent logic structure: plugins are testable, the planner is inspectable, new tools can be added without rewriting orchestration logic.

**Why MCP integration (LAB 9)?**
Model Context Protocol is where agent-tool connectivity is heading. Building on it now means the architecture stays current. I don't want to maintain bespoke integrations that become obsolete in 18 months.

---

## Azure AI services used

| Service | Role | Lab |
|---|---|---|
| Azure OpenAI GPT-4o | Core reasoning, grounded summaries | LAB 1, 2 |
| Azure AI Evaluation SDK | Continuous scoring: Groundedness, Coherence, Fluency, Relevance | LAB 5 |
| Azure Content Safety | Output gate — toxicity, harm, PII classification | LAB 4 |
| Azure AI Language — NER | PII detection and redaction | LAB 11 |
| Azure AI Language — Classifier | Document type routing | LAB 13 |
| Azure AI Search | RAG retrieval index, knowledge mining | LAB 3, 26 |
| Azure AI Agent Service | Document analysis agent, multi-agent pipeline | LAB 7, 8 |
| MCP Tool Integration | Live external API connectivity for agents | LAB 9 |
| Semantic Kernel | Agent orchestration, plugin architecture | LAB 10 |
| Azure AI Document Intelligence | Invoice, receipt, custom form extraction | LAB 24, 25 |
| Azure AI Vision — OCR | Text from scanned documents | LAB 17 |
| Azure AI Speech | STT + TTS for voice interface | LAB 14, 15 |
| Azure AI Foundry | Model deployment, versioning, project management | LAB 1 |

---

## Project structure

```
ai-governance-dashboard/
│
├── evaluation/
│   ├── eval_harness.py          # Scheduled evaluation runner (LAB 5)
│   ├── metrics_store.py         # Time-series score persistence
│   └── drift_detector.py        # 7-day rolling window drift detection
│
├── safety/
│   ├── content_filter.py        # Azure Content Safety gate (LAB 4)
│   ├── pii_redactor.py          # NER-based PII redaction (LAB 11)
│   └── output_validator.py      # Pre-delivery output check
│
├── policy/
│   ├── policy_engine.py         # Rule evaluation and enforcement
│   ├── rules.yaml               # Policy-as-code definitions
│   └── incident_manager.py      # Incident creation and routing
│
├── agents/
│   ├── sk_orchestrator.py       # Semantic Kernel kernel + plugins (LAB 10)
│   ├── document_agent.py        # Single document agent (LAB 7)
│   ├── multi_agent_pipeline.py  # Intake to Analysis to Report (LAB 8)
│   └── mcp_tools.py             # External tool connections (LAB 9)
│
├── rag/
│   ├── indexer.py               # Azure AI Search indexing (LAB 3, 26)
│   └── retriever.py             # Grounded retrieval pipeline
│
├── extraction/
│   ├── ocr.py                   # LAB 17
│   ├── doc_intelligence.py      # LAB 24, 25
│   └── ner_pipeline.py          # LAB 11
│
├── dashboard/
│   └── ai-governance-dashboard.jsx
│
├── .env.example
├── requirements.txt
└── README.md
```

---

## What I'd do differently in a real engagement

I've thought about the gaps because I've shipped enough systems to know they exist:

**Multi-tenancy** — each business unit needs its own policy namespace and incident queue. The current design assumes a single tenant.

**Evaluation dataset drift** — the eval harness is only as good as its golden dataset. If the dataset becomes stale, scores look fine while quality degrades. I'd build a dataset refresh pipeline alongside the eval harness.

**Cost attribution** — aggregate 30-day spend is useful. Attributing it to specific teams, projects, and engagement codes is what finance actually needs. That requires a tagging strategy from day one.

**Human-in-the-loop escalation** — the policy engine currently auto-acts. For HIGH severity incidents in a regulated environment, a human review step with a proper handoff workflow is non-negotiable.

**Model cards** — every deployed model should have a living model card: training data, intended use, known limitations, evaluation results. I'd automate model card generation from eval harness output.

---

## Interview talking points

**"Tell me about a project you built with Azure AI."**

I built a governance dashboard rather than a feature demo, because after 16 years I know that building AI is the straightforward part — governing it in production is the hard part. The dashboard gives a single view across every deployed model: evaluation scores running continuously via the Azure AI Evaluation SDK, a policy engine with codified rules for groundedness, PII, and toxicity, and a structured incident log with full audit trail. I deliberately chose architecture patterns I can defend under questioning.

**"Why not a chatbot?"**

Chatbots are demos. What separates an AI engineer from someone who followed a tutorial is understanding that a model deployed without evaluation, safety gates, drift detection, and cost governance is a liability, not an asset. I built the infrastructure layer because that's where the real engineering is.

**"What tradeoffs did you make?"**

RAG over fine-tuning: updatable knowledge, auditable citations, lower cost — at the cost of retrieval latency. Semantic Kernel over direct API calls: structured, testable orchestration — at the cost of an additional dependency. Policy-as-code: auditable, enforceable governance — requires upfront discipline to define rules before deployment.

**"What would you do differently?"**

Multi-tenancy, evaluation dataset refresh pipeline, cost attribution by engagement code, automated model cards. I know where the gaps are because I've thought past the demo.

---

*Built on 26 Azure AI labs. Designed with 16 years of production systems experience.*
