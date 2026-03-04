import { useState, useEffect, useRef } from "react";

// ─── Design Tokens ─────────────────────────────────────────────────────────
const T = {
  bg:       "#0a0e1a",
  surface:  "#111827",
  card:     "#151d2e",
  border:   "#1e2d45",
  accent:   "#3b82f6",
  accentDim:"#1d4ed8",
  green:    "#10b981",
  amber:    "#f59e0b",
  red:      "#ef4444",
  muted:    "#64748b",
  text:     "#e2e8f0",
  textDim:  "#94a3b8",
  font:     "'IBM Plex Mono', 'Fira Code', monospace",
  sans:     "'Sora', 'DM Sans', sans-serif",
};

// ─── Data ──────────────────────────────────────────────────────────────────
const MODELS = [
  {
    id: "gpt4o-audit",
    name: "GPT-4o · Audit Reasoner",
    owner: "Risk & Compliance",
    env: "PRODUCTION",
    version: "2025-01-15",
    status: "healthy",
    groundedness: 94.2,
    coherence: 91.7,
    fluency: 96.3,
    relevance: 89.5,
    toxicity: 0.3,
    pii_leaked: 0,
    requests_24h: 18420,
    p95_latency: 1840,
    cost_30d: 42800,
    drift_flag: false,
    rag: true,
    safety_filter: true,
    labs: ["LAB 3 — RAG", "LAB 4 — Safety", "LAB 5 — Eval"],
  },
  {
    id: "classifier-doc",
    name: "Custom Classifier · Doc Type",
    owner: "Document Processing",
    env: "PRODUCTION",
    version: "v2.1.0",
    status: "degraded",
    groundedness: 78.1,
    coherence: 82.4,
    fluency: 88.0,
    relevance: 74.9,
    toxicity: 0.0,
    pii_leaked: 0,
    requests_24h: 63100,
    p95_latency: 210,
    cost_30d: 8400,
    drift_flag: true,
    rag: false,
    safety_filter: false,
    labs: ["LAB 13 — Classifier", "LAB 5 — Eval"],
  },
  {
    id: "agent-multiagent",
    name: "Multi-Agent Pipeline · Intake",
    owner: "Audit Automation",
    env: "STAGING",
    version: "v0.9.2-rc",
    status: "healthy",
    groundedness: 91.0,
    coherence: 88.6,
    fluency: 93.1,
    relevance: 87.3,
    toxicity: 0.1,
    pii_leaked: 0,
    requests_24h: 2100,
    p95_latency: 6200,
    cost_30d: 15600,
    drift_flag: false,
    rag: true,
    safety_filter: true,
    labs: ["LAB 7 — Agent", "LAB 8 — Multi-Agent", "LAB 9 — MCP"],
  },
  {
    id: "doc-intel-invoice",
    name: "Doc Intelligence · Invoice",
    owner: "Finance Operations",
    env: "PRODUCTION",
    version: "prebuilt-2024-02",
    status: "healthy",
    groundedness: 97.4,
    coherence: 95.0,
    fluency: 97.0,
    relevance: 96.2,
    toxicity: 0.0,
    pii_leaked: 0,
    requests_24h: 9800,
    p95_latency: 980,
    cost_30d: 19200,
    drift_flag: false,
    rag: false,
    safety_filter: false,
    labs: ["LAB 24 — Prebuilt", "LAB 25 — Custom"],
  },
  {
    id: "speech-voice",
    name: "Speech Pipeline · STT+TTS",
    owner: "Accessibility Team",
    env: "PRODUCTION",
    version: "JennyNeural-v3",
    status: "healthy",
    groundedness: null,
    coherence: null,
    fluency: 98.2,
    relevance: null,
    toxicity: 0.0,
    pii_leaked: 2,
    requests_24h: 4400,
    p95_latency: 620,
    cost_30d: 7100,
    drift_flag: false,
    rag: false,
    safety_filter: true,
    labs: ["LAB 14 — Speech", "LAB 15 — Voice Chat"],
  },
];

const INCIDENTS = [
  { id: "INC-0041", model: "Custom Classifier · Doc Type", severity: "HIGH", type: "Metric Drift", msg: "Relevance score dropped 8.3 pts over 7 days — retraining recommended.", ts: "2h ago", open: true },
  { id: "INC-0039", model: "Speech Pipeline · STT+TTS", severity: "MEDIUM", type: "PII Leak", msg: "2 PII entities (Aadhaar numbers) surfaced in TTS output. Redaction rule updated.", ts: "14h ago", open: true },
  { id: "INC-0038", model: "GPT-4o · Audit Reasoner", severity: "LOW", type: "Latency Spike", msg: "P95 latency exceeded 3s SLA for 22 min during peak load. Auto-scaled.", ts: "1d ago", open: false },
  { id: "INC-0034", model: "Multi-Agent Pipeline · Intake", severity: "LOW", type: "Tool Timeout", msg: "MCP vendor API timed out 4 times. Retry logic handled gracefully.", ts: "3d ago", open: false },
];

const EVAL_HISTORY = [
  { week: "W-5", groundedness: 95.1, relevance: 91.2, toxicity: 0.2 },
  { week: "W-4", groundedness: 94.8, relevance: 90.8, toxicity: 0.3 },
  { week: "W-3", groundedness: 94.5, relevance: 89.9, toxicity: 0.3 },
  { week: "W-2", groundedness: 94.0, relevance: 88.1, toxicity: 0.4 },
  { week: "W-1", groundedness: 94.2, relevance: 89.5, toxicity: 0.3 },
];

const POLICY_RULES = [
  { id: "POL-01", name: "Groundedness Threshold", condition: "< 80%", action: "Alert + Block deployment", status: "active" },
  { id: "POL-02", name: "PII Leak Tolerance", condition: "> 0 per 10k requests", action: "Immediate incident + redaction patch", status: "active" },
  { id: "POL-03", name: "Toxicity Gate", condition: "> 1.0%", action: "Route to human review queue", status: "active" },
  { id: "POL-04", name: "Latency SLA", condition: "P95 > 3s for > 15 min", action: "Auto-scale + page on-call", status: "active" },
  { id: "POL-05", name: "Drift Detection Window", condition: "Score drop > 5pts in 7 days", action: "Flag for retraining", status: "active" },
  { id: "POL-06", name: "Cost Anomaly", condition: "> 30% MoM spike", action: "Capacity review triggered", status: "draft" },
];

// ─── Micro Components ──────────────────────────────────────────────────────
const StatusDot = ({ status }) => {
  const c = { healthy: T.green, degraded: T.amber, down: T.red }[status];
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
      <span style={{
        width: 7, height: 7, borderRadius: "50%", background: c,
        boxShadow: `0 0 6px ${c}`,
        animation: status === "degraded" ? "pulse 1.4s ease infinite" : "none"
      }} />
      <span style={{ fontSize: 11, color: c, fontFamily: T.font, letterSpacing: 1, textTransform: "uppercase" }}>{status}</span>
    </span>
  );
};

const EnvBadge = ({ env }) => {
  const styles = {
    PRODUCTION: { bg: "#0f2a1a", color: T.green, border: "#134d2a" },
    STAGING:    { bg: "#1a1a0f", color: T.amber, border: "#4d3a00" },
    DEV:        { bg: "#0f1a2a", color: T.accent, border: "#1d3a5a" },
  };
  const s = styles[env] || styles.DEV;
  return (
    <span style={{
      background: s.bg, color: s.color, border: `1px solid ${s.border}`,
      padding: "1px 8px", borderRadius: 3, fontSize: 10,
      fontFamily: T.font, letterSpacing: 1.5, fontWeight: 700
    }}>{env}</span>
  );
};

const Score = ({ value, label, threshold = 80 }) => {
  if (value === null) return <div style={{ fontSize: 11, color: T.muted }}>N/A</div>;
  const color = value >= threshold ? T.green : value >= threshold - 10 ? T.amber : T.red;
  return (
    <div style={{ textAlign: "center" }}>
      <div style={{ fontSize: 18, fontWeight: 800, color, fontFamily: T.font, lineHeight: 1 }}>{value.toFixed(1)}</div>
      <div style={{ fontSize: 10, color: T.muted, marginTop: 3, letterSpacing: 0.5 }}>{label}</div>
      <div style={{ height: 2, background: T.border, borderRadius: 1, marginTop: 5 }}>
        <div style={{ width: `${value}%`, height: "100%", background: color, borderRadius: 1, transition: "width 1.2s ease" }} />
      </div>
    </div>
  );
};

const Severity = ({ level }) => {
  const c = { HIGH: T.red, MEDIUM: T.amber, LOW: T.accent }[level];
  return (
    <span style={{
      color: c, border: `1px solid ${c}44`, background: `${c}11`,
      padding: "2px 8px", borderRadius: 3, fontSize: 10,
      fontFamily: T.font, fontWeight: 700, letterSpacing: 1
    }}>{level}</span>
  );
};

// Mini sparkline
const Sparkline = ({ data, color = T.accent }) => {
  const w = 80, h = 28;
  const vals = data.map(d => d.groundedness);
  const min = Math.min(...vals), max = Math.max(...vals);
  const pts = vals.map((v, i) => {
    const x = (i / (vals.length - 1)) * w;
    const y = h - ((v - min) / (max - min + 1)) * h;
    return `${x},${y}`;
  }).join(" ");
  return (
    <svg width={w} height={h} style={{ overflow: "visible" }}>
      <polyline points={pts} fill="none" stroke={color} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" />
      {vals.map((v, i) => {
        const x = (i / (vals.length - 1)) * w;
        const y = h - ((v - min) / (max - min + 1)) * h;
        return i === vals.length - 1
          ? <circle key={i} cx={x} cy={y} r={3} fill={color} />
          : null;
      })}
    </svg>
  );
};

// ─── Sections ──────────────────────────────────────────────────────────────
function TopBar({ tab, setTab }) {
  const tabs = ["overview", "models", "incidents", "policy"];
  return (
    <div style={{
      background: T.surface, borderBottom: `1px solid ${T.border}`,
      padding: "0 28px", display: "flex", alignItems: "center",
      justifyContent: "space-between", height: 52, position: "sticky", top: 0, zIndex: 50
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
        <div style={{ fontFamily: T.font, fontSize: 13, color: T.accent, letterSpacing: 2, fontWeight: 700 }}>
          AI·GOV
        </div>
        <div style={{ width: 1, height: 18, background: T.border }} />
        <div style={{ fontFamily: T.sans, fontSize: 13, color: T.textDim }}>Enterprise AI Governance</div>
        <div style={{
          background: `${T.green}15`, color: T.green, border: `1px solid ${T.green}44`,
          padding: "2px 10px", borderRadius: 3, fontSize: 10, fontFamily: T.font, letterSpacing: 1.5
        }}>4/5 MODELS HEALTHY</div>
      </div>
      <div style={{ display: "flex", gap: 2 }}>
        {tabs.map(t => (
          <button key={t} onClick={() => setTab(t)} style={{
            background: tab === t ? `${T.accent}18` : "transparent",
            border: "none", borderBottom: tab === t ? `2px solid ${T.accent}` : "2px solid transparent",
            color: tab === t ? T.accent : T.muted, padding: "14px 18px",
            fontSize: 12, fontFamily: T.sans, fontWeight: 600,
            cursor: "pointer", letterSpacing: 0.5, textTransform: "capitalize",
            transition: "all 0.15s"
          }}>{t}</button>
        ))}
      </div>
      <div style={{ fontFamily: T.font, fontSize: 11, color: T.muted }}>
        {new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })} · Azure AI Foundry
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, color = T.accent, alert = false }) {
  return (
    <div style={{
      background: T.card, border: `1px solid ${alert ? T.amber + "88" : T.border}`,
      borderRadius: 10, padding: "18px 22px",
      boxShadow: alert ? `0 0 16px ${T.amber}18` : "none"
    }}>
      <div style={{ fontFamily: T.font, fontSize: 11, color: T.muted, letterSpacing: 1.5, marginBottom: 8 }}>{label.toUpperCase()}</div>
      <div style={{ fontFamily: T.font, fontSize: 28, fontWeight: 800, color, lineHeight: 1 }}>{value}</div>
      {sub && <div style={{ fontFamily: T.sans, fontSize: 11, color: T.muted, marginTop: 6 }}>{sub}</div>}
    </div>
  );
}

function Overview() {
  const totalReqs = MODELS.reduce((a, m) => a + m.requests_24h, 0);
  const totalCost = MODELS.reduce((a, m) => a + m.cost_30d, 0);
  const openInc = INCIDENTS.filter(i => i.open).length;
  const avgGround = (MODELS.filter(m => m.groundedness).reduce((a, m) => a + m.groundedness, 0) / MODELS.filter(m => m.groundedness).length).toFixed(1);

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h2 style={{ fontFamily: T.sans, fontWeight: 800, fontSize: 20, color: T.text }}>System Overview</h2>
        <p style={{ color: T.muted, fontSize: 13, marginTop: 4, fontFamily: T.sans }}>
          Real-time health across all deployed Azure AI models — evaluation scores, incidents, cost, and policy compliance.
        </p>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14, marginBottom: 24 }}>
        <StatCard label="Avg Groundedness" value={`${avgGround}%`} sub="Across RAG-enabled models" color={T.green} />
        <StatCard label="Requests / 24h" value={totalReqs.toLocaleString()} sub="Across all deployments" color={T.accent} />
        <StatCard label="Open Incidents" value={openInc} sub="1 HIGH severity" color={T.amber} alert={openInc > 0} />
        <StatCard label="AI Spend / 30d" value={`₹${(totalCost / 1000).toFixed(1)}k`} sub="Within approved budget" color={T.textDim} />
      </div>

      {/* Model Health Grid */}
      <div style={{ fontFamily: T.font, fontSize: 10, color: T.muted, letterSpacing: 2, marginBottom: 12 }}>MODEL HEALTH MATRIX</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {MODELS.map(m => (
          <div key={m.id} style={{
            background: T.card, border: `1px solid ${m.drift_flag ? T.amber + "66" : T.border}`,
            borderRadius: 8, padding: "14px 20px",
            display: "grid", gridTemplateColumns: "2fr 120px 80px repeat(4, 80px) 100px",
            alignItems: "center", gap: 12
          }}>
            <div>
              <div style={{ fontFamily: T.sans, fontWeight: 700, fontSize: 13, color: T.text }}>{m.name}</div>
              <div style={{ fontSize: 11, color: T.muted, marginTop: 2, fontFamily: T.sans }}>
                {m.owner} · <EnvBadge env={m.env} />
                {m.drift_flag && <span style={{ marginLeft: 8, color: T.amber, fontSize: 10, fontFamily: T.font }}>⚠ DRIFT</span>}
              </div>
            </div>
            <StatusDot status={m.status} />
            <div style={{ textAlign: "center" }}>
              <Sparkline data={EVAL_HISTORY} color={m.status === "degraded" ? T.amber : T.accent} />
            </div>
            <Score value={m.groundedness} label="Ground." />
            <Score value={m.coherence} label="Coher." />
            <Score value={m.fluency} label="Fluency" />
            <Score value={m.relevance} label="Relev." />
            <div style={{ textAlign: "right" }}>
              <div style={{ fontFamily: T.font, fontSize: 12, color: T.textDim }}>{m.requests_24h.toLocaleString()}<span style={{ fontSize: 9, color: T.muted }}> req/24h</span></div>
              <div style={{ fontFamily: T.font, fontSize: 12, color: T.muted, marginTop: 3 }}>{m.p95_latency}ms <span style={{ fontSize: 9 }}>p95</span></div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function Models({ selected, setSelected }) {
  const m = selected || MODELS[0];
  return (
    <div style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: 18 }}>
      {/* Sidebar */}
      <div>
        <div style={{ fontFamily: T.font, fontSize: 10, color: T.muted, letterSpacing: 2, marginBottom: 12 }}>DEPLOYMENTS</div>
        {MODELS.map(mo => (
          <div key={mo.id} onClick={() => setSelected(mo)} style={{
            background: m.id === mo.id ? `${T.accent}14` : T.card,
            border: `1px solid ${m.id === mo.id ? T.accent + "55" : T.border}`,
            borderRadius: 8, padding: "12px 16px", cursor: "pointer", marginBottom: 6,
            transition: "all 0.15s"
          }}>
            <div style={{ fontFamily: T.sans, fontWeight: 700, fontSize: 12, color: m.id === mo.id ? T.accent : T.text }}>{mo.name}</div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
              <StatusDot status={mo.status} />
              <EnvBadge env={mo.env} />
            </div>
          </div>
        ))}
      </div>

      {/* Detail */}
      <div>
        <div style={{ background: T.card, border: `1px solid ${T.border}`, borderRadius: 10, padding: "22px 26px", marginBottom: 16 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 20 }}>
            <div>
              <div style={{ fontFamily: T.sans, fontWeight: 800, fontSize: 18, color: T.text }}>{m.name}</div>
              <div style={{ color: T.muted, fontSize: 12, marginTop: 4, fontFamily: T.sans }}>
                Owner: {m.owner} · Version: <span style={{ fontFamily: T.font, color: T.textDim }}>{m.version}</span>
              </div>
            </div>
            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <EnvBadge env={m.env} />
              <StatusDot status={m.status} />
            </div>
          </div>

          {/* Eval Scores */}
          <div style={{ fontFamily: T.font, fontSize: 10, color: T.muted, letterSpacing: 2, marginBottom: 14 }}>EVALUATION SCORES · Azure AI Evaluation SDK (LAB 5)</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 16, marginBottom: 20 }}>
            {[
              { v: m.groundedness, l: "Groundedness", t: 80 },
              { v: m.coherence, l: "Coherence", t: 80 },
              { v: m.fluency, l: "Fluency", t: 85 },
              { v: m.relevance, l: "Relevance", t: 80 },
            ].map((s, i) => (
              <div key={i} style={{ background: T.surface, borderRadius: 8, padding: "14px 16px", border: `1px solid ${T.border}` }}>
                <Score value={s.v} label={s.l} threshold={s.t} />
              </div>
            ))}
          </div>

          {/* Flags */}
          <div style={{ display: "flex", gap: 12, marginBottom: 20, flexWrap: "wrap" }}>
            {[
              { label: "RAG Grounding", active: m.rag, lab: "LAB 3" },
              { label: "Content Safety", active: m.safety_filter, lab: "LAB 4" },
              { label: "Drift Flag", active: m.drift_flag, warn: true },
              { label: "PII Events", active: m.pii_leaked > 0, warn: true, count: m.pii_leaked },
            ].map((f, i) => (
              <div key={i} style={{
                padding: "6px 14px", borderRadius: 6, fontSize: 11, fontFamily: T.font,
                fontWeight: 600, border: "1px solid",
                background: f.active ? (f.warn ? `${T.amber}15` : `${T.green}12`) : T.surface,
                color: f.active ? (f.warn ? T.amber : T.green) : T.muted,
                borderColor: f.active ? (f.warn ? T.amber + "44" : T.green + "44") : T.border,
              }}>
                {f.active ? (f.warn ? "⚠ " : "✓ ") : "○ "}{f.label}
                {f.lab && f.active && <span style={{ opacity: 0.6, marginLeft: 6 }}>{f.lab}</span>}
                {f.count > 0 && ` (${f.count})`}
              </div>
            ))}
          </div>

          {/* Operational */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12 }}>
            {[
              { label: "Requests / 24h", value: m.requests_24h.toLocaleString() },
              { label: "P95 Latency", value: `${m.p95_latency} ms` },
              { label: "Spend / 30d", value: `₹${m.cost_30d.toLocaleString()}` },
            ].map((s, i) => (
              <div key={i} style={{ background: T.surface, borderRadius: 8, padding: "12px 16px", border: `1px solid ${T.border}` }}>
                <div style={{ fontSize: 10, color: T.muted, fontFamily: T.font, letterSpacing: 1.5 }}>{s.label.toUpperCase()}</div>
                <div style={{ fontSize: 20, fontWeight: 800, color: T.text, fontFamily: T.font, marginTop: 6 }}>{s.value}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Azure Labs */}
        <div style={{ background: T.card, border: `1px solid ${T.border}`, borderRadius: 10, padding: "18px 22px" }}>
          <div style={{ fontFamily: T.font, fontSize: 10, color: T.muted, letterSpacing: 2, marginBottom: 12 }}>AZURE AI CAPABILITIES POWERING THIS MODEL</div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            {m.labs.map((l, i) => (
              <span key={i} style={{
                background: `${T.accent}14`, color: T.accent, border: `1px solid ${T.accent}33`,
                padding: "5px 14px", borderRadius: 5, fontSize: 12, fontFamily: T.font, fontWeight: 600
              }}>{l}</span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Incidents() {
  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h2 style={{ fontFamily: T.sans, fontWeight: 800, fontSize: 20, color: T.text }}>Incident Log</h2>
        <p style={{ color: T.muted, fontSize: 13, marginTop: 4, fontFamily: T.sans }}>
          AI-specific incidents — drift, PII leaks, latency breaches, tool failures. Full audit trail.
        </p>
      </div>
      {INCIDENTS.map(inc => (
        <div key={inc.id} style={{
          background: T.card, border: `1px solid ${inc.open ? (inc.severity === "HIGH" ? T.red + "55" : T.amber + "44") : T.border}`,
          borderRadius: 10, padding: "18px 22px", marginBottom: 12,
          boxShadow: inc.severity === "HIGH" && inc.open ? `0 0 20px ${T.red}14` : "none"
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}>
              <div>
                <div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 6 }}>
                  <span style={{ fontFamily: T.font, fontSize: 12, color: T.muted }}>{inc.id}</span>
                  <Severity level={inc.severity} />
                  <span style={{
                    fontSize: 10, fontFamily: T.font, color: T.textDim,
                    background: T.surface, border: `1px solid ${T.border}`, padding: "1px 8px", borderRadius: 3
                  }}>{inc.type}</span>
                  {inc.open
                    ? <span style={{ fontSize: 10, fontFamily: T.font, color: T.red }}>● OPEN</span>
                    : <span style={{ fontSize: 10, fontFamily: T.font, color: T.green }}>✓ RESOLVED</span>
                  }
                </div>
                <div style={{ fontFamily: T.sans, fontSize: 14, color: T.text, fontWeight: 600, marginBottom: 6 }}>{inc.model}</div>
                <div style={{ fontFamily: T.sans, fontSize: 13, color: T.muted, lineHeight: 1.6 }}>{inc.msg}</div>
              </div>
            </div>
            <span style={{ fontFamily: T.font, fontSize: 11, color: T.muted, whiteSpace: "nowrap" }}>{inc.ts}</span>
          </div>
        </div>
      ))}

      <div style={{
        background: T.card, border: `1px solid ${T.border}`, borderRadius: 10, padding: "18px 22px", marginTop: 20
      }}>
        <div style={{ fontFamily: T.font, fontSize: 10, color: T.muted, letterSpacing: 2, marginBottom: 14 }}>WHY AN INCIDENT LOG MATTERS IN PRODUCTION AI</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
          {[
            { q: "Metric Drift (INC-0041)", a: "Classifier trained on 6-month-old data. Real-world document formats shifted. Solution: automated drift detection triggers retraining pipeline." },
            { q: "PII Leak (INC-0039)", a: "Aadhaar numbers transcribed by STT passed to TTS output without redaction. Language AI NER rule updated. LAB 11 now part of speech pipeline." },
            { q: "Latency Spike (INC-0038)", a: "GPT-4o context window hit under peak load. Azure auto-scaling resolved in 22 min. Pre-warmed instances now provisioned." },
            { q: "Tool Timeout (INC-0034)", a: "MCP external vendor API went down. Agent retry logic (LAB 9) handled gracefully with exponential backoff — no user impact." },
          ].map((item, i) => (
            <div key={i} style={{ background: T.surface, borderRadius: 8, padding: "14px 16px", border: `1px solid ${T.border}` }}>
              <div style={{ fontFamily: T.font, fontSize: 11, color: T.accent, marginBottom: 8 }}>{item.q}</div>
              <div style={{ fontFamily: T.sans, fontSize: 12, color: T.muted, lineHeight: 1.6 }}>{item.a}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Policy() {
  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h2 style={{ fontFamily: T.sans, fontWeight: 800, fontSize: 20, color: T.text }}>AI Policy Engine</h2>
        <p style={{ color: T.muted, fontSize: 13, marginTop: 4, fontFamily: T.sans }}>
          Codified rules that govern every model in production. Policy-as-code for responsible AI.
        </p>
      </div>

      <div style={{ background: T.card, border: `1px solid ${T.border}`, borderRadius: 10, marginBottom: 18, overflow: "hidden" }}>
        <div style={{ padding: "14px 22px", borderBottom: `1px solid ${T.border}`, display: "grid", gridTemplateColumns: "80px 1fr 160px 1fr 80px", gap: 16 }}>
          {["ID", "Policy Rule", "Trigger Condition", "Automated Action", "Status"].map((h, i) => (
            <div key={i} style={{ fontFamily: T.font, fontSize: 10, color: T.muted, letterSpacing: 1.5 }}>{h.toUpperCase()}</div>
          ))}
        </div>
        {POLICY_RULES.map((rule, i) => (
          <div key={rule.id} style={{
            padding: "14px 22px", borderBottom: i < POLICY_RULES.length - 1 ? `1px solid ${T.border}` : "none",
            display: "grid", gridTemplateColumns: "80px 1fr 160px 1fr 80px", gap: 16, alignItems: "center"
          }}>
            <div style={{ fontFamily: T.font, fontSize: 11, color: T.muted }}>{rule.id}</div>
            <div style={{ fontFamily: T.sans, fontSize: 13, color: T.text, fontWeight: 600 }}>{rule.name}</div>
            <div style={{ fontFamily: T.font, fontSize: 11, color: T.amber, background: `${T.amber}12`, border: `1px solid ${T.amber}33`, padding: "3px 10px", borderRadius: 4 }}>{rule.condition}</div>
            <div style={{ fontFamily: T.sans, fontSize: 12, color: T.muted }}>{rule.action}</div>
            <div>
              <span style={{
                fontSize: 10, fontFamily: T.font, fontWeight: 700, letterSpacing: 1,
                color: rule.status === "active" ? T.green : T.muted,
                background: rule.status === "active" ? `${T.green}15` : T.surface,
                border: `1px solid ${rule.status === "active" ? T.green + "44" : T.border}`,
                padding: "2px 8px", borderRadius: 3
              }}>{rule.status.toUpperCase()}</span>
            </div>
          </div>
        ))}
      </div>

      <div style={{
        background: `linear-gradient(135deg, #0d1b36 0%, #0a1628 100%)`,
        border: `1px solid ${T.accent}33`, borderRadius: 12, padding: "24px 28px"
      }}>
        <div style={{ fontFamily: T.font, fontSize: 10, color: T.accent, letterSpacing: 2.5, marginBottom: 14 }}>THE SENIOR ENGINEER'S INSIGHT</div>
        <div style={{ fontFamily: T.sans, fontSize: 15, color: T.text, fontWeight: 700, marginBottom: 14, lineHeight: 1.5 }}>
          "The hardest part of AI in the enterprise isn't building the model. It's governing it after go-live."
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 14 }}>
          {[
            {
              title: "What I learned from 16 years",
              body: "Every enterprise system degrades silently. AI models drift just like any other dependency. I built this governance layer because I've seen what happens when you don't."
            },
            {
              title: "Why policy-as-code matters",
              body: "Verbal agreements on AI behaviour don't survive team turnover. Codified policy rules (groundedness thresholds, PII tolerance) make governance auditable and transferable."
            },
            {
              title: "Responsible AI isn't a checkbox",
              body: "Content filters (LAB 4) and evaluation harnesses (LAB 5) aren't extras — they're the difference between a demo and a production system. I treat them as first-class components."
            },
          ].map((c, i) => (
            <div key={i} style={{ background: T.surface, borderRadius: 8, padding: "14px 16px", border: `1px solid ${T.border}` }}>
              <div style={{ fontFamily: T.font, fontSize: 11, color: T.accent, marginBottom: 8 }}>{c.title}</div>
              <div style={{ fontFamily: T.sans, fontSize: 12, color: T.muted, lineHeight: 1.7 }}>{c.body}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── App ───────────────────────────────────────────────────────────────────
export default function App() {
  const [tab, setTab] = useState("overview");
  const [selectedModel, setSelectedModel] = useState(MODELS[0]);

  return (
    <div style={{ background: T.bg, minHeight: "100vh", color: T.text }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600;700&family=Sora:wght@400;600;700;800&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-thumb { background: #1e2d45; border-radius: 2px; }
        @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }
      `}</style>

      <TopBar tab={tab} setTab={setTab} />

      <div style={{ maxWidth: 1240, margin: "0 auto", padding: "28px 24px" }}>
        {tab === "overview" && <Overview />}
        {tab === "models" && <Models selected={selectedModel} setSelected={setSelectedModel} />}
        {tab === "incidents" && <Incidents />}
        {tab === "policy" && <Policy />}
      </div>
    </div>
  );
}
