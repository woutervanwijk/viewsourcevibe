// Shared by report.html and the batch summary page.
const reportCss = r'''<style>
    body { margin: 0; font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #1f2937; background: #f8fafc; }
    main { max-width: 1040px; margin: 0 auto; padding: 32px 20px 48px; }
    h1 { margin: 0 0 6px; font-size: 28px; }
    h2 { margin: 28px 0 12px; font-size: 18px; }
    h3 { margin: 18px 0 10px; font-size: 15px; }
    a { color: #0369a1; }
    .muted { color: #64748b; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
    .card { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px 16px; }
    .label { display: block; color: #64748b; font-size: 12px; }
    .value { font-weight: 650; overflow-wrap: anywhere; }
    table { width: 100%; border-collapse: collapse; background: white; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; }
    th, td { text-align: left; padding: 9px 10px; border-bottom: 1px solid #e2e8f0; vertical-align: top; }
    th { background: #eef2f7; font-size: 12px; color: #475569; }
    tr:last-child td { border-bottom: 0; }
    code { background: #e2e8f0; padding: 2px 5px; border-radius: 4px; }
    .pill { display: inline-block; padding: 2px 8px; border: 1px solid #cbd5e1; border-radius: 999px; margin: 2px 4px 2px 0; background: #fff; }
    details { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px 12px; margin-top: 12px; }
    summary { cursor: pointer; font-weight: 650; }
    pre { overflow: auto; white-space: pre-wrap; word-break: break-word; background: #0f172a; color: #e2e8f0; border-radius: 8px; padding: 12px; }
  </style>''';
