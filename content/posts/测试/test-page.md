+++
date = '2026-06-05T15:44:20+08:00'
draft = false
title = '测试页面'
tags = ["测试", "HTML"]
categories = ["测试"]
+++

<style>
  .test-container {
    max-width: 720px;
    margin: 0 auto;
    padding: 1rem 0;
    line-height: 1.6;
  }
  .test-container h1 { color: #2563eb; }
  .test-card {
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1.5rem;
    margin: 1rem 0;
    background: #f9fafb;
  }
  .test-tag {
    display: inline-block;
    background: #dbeafe;
    color: #1e40af;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 0.875rem;
    margin-right: 4px;
  }
</style>

<div class="test-container">
  <h1>Hello, World!</h1>
  <p>这是一个由 Hugo 渲染的静态 HTML 测试页面。</p>

  <div class="test-card">
    <h2>信息</h2>
    <ul>
      <li><strong>框架：</strong>Hugo</li>
      <li><strong>主题：</strong>Lvzh</li>
      <li><strong>日期：</strong>2026-06-05</li>
    </ul>
  </div>

  <p>
    <span class="test-tag">测试</span>
    <span class="test-tag">HTML</span>
    <span class="test-tag">Hugo</span>
  </p>
</div>
