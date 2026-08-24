(() => {
  let csrf = '';
  let role = '';
  const $ = (id) => document.getElementById(id);
  const api = async (path, options = {}) => {
    const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
    if (csrf && options.method && options.method !== 'GET') headers['X-CSRF-Token'] = csrf;
    const response = await fetch('/KairosAdmin/api' + path, { credentials: 'same-origin', ...options, headers });
    const body = response.status === 204 ? null : await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body.message || '请求失败');
    return body;
  };
  const show = (id, visible) => $(id).classList.toggle('hidden', !visible);
  const text = (value) => { const node = document.createTextNode(value ?? ''); return node; };
  const renderGroups = async () => {
    const container = $('groups'); container.replaceChildren();
    const data = await api('/groups');
    for (const group of data.groups || []) {
      const item = document.createElement('article'); item.className = 'item';
      const head = document.createElement('div'); head.className = 'item-head';
      const title = document.createElement('strong'); title.append(text(group.name));
      const badge = document.createElement('span'); badge.className = 'badge'; badge.append(text(group.collaboration_enabled_at ? '协作已开启' : '协作关闭'));
      head.append(title, badge); item.append(head);
      const meta = document.createElement('div'); meta.className = 'meta'; meta.append(text('群组 ID ' + group.id)); item.append(meta);
      const accounts = document.createElement('div'); accounts.className = 'accounts'; accounts.append(text('加载花名册中...')); item.append(accounts); container.append(item);
      try { const result = await api('/groups/' + encodeURIComponent(group.id) + '/accounts'); accounts.replaceChildren(); for (const account of result.accounts || []) { const row = document.createElement('div'); row.className = 'account'; const label = document.createElement('span'); label.append(text(account.display_name + ' · ' + account.account_code)); const roleBadge = document.createElement('span'); roleBadge.className = 'badge'; roleBadge.append(text(account.role + (account.active ? '' : ' · 停用'))); row.append(label, roleBadge); accounts.append(row); } if (!result.accounts?.length) accounts.append(text('暂无花名册账号')); } catch (error) { accounts.replaceChildren(); accounts.append(text(error.message)); }
    }
    if (!data.groups?.length) container.append(text('暂无可管理群组'));
  };
  const renderUsers = async () => { const container = $('users'); container.replaceChildren(); const data = await api('/users'); for (const user of data.users || []) { const item = document.createElement('article'); item.className = 'item'; const head = document.createElement('div'); head.className = 'item-head'; const title = document.createElement('strong'); title.append(text(user.username)); const badge = document.createElement('span'); badge.className = 'badge'; badge.append(text(user.disabled_at ? '已停用' : (user.role || 'L1'))); head.append(title, badge); item.append(head); const meta = document.createElement('div'); meta.className = 'meta'; meta.append(text(user.id)); item.append(meta); container.append(item); } if (!data.users?.length) container.append(text('暂无服务器账号')); };
  const refresh = async (fn, errorId) => { try { $(errorId).textContent = ''; await fn(); } catch (error) { $(errorId).textContent = error.message; } };
  $('login-form').addEventListener('submit', async (event) => { event.preventDefault(); $('login-error').textContent = ''; const form = new FormData(event.currentTarget); try { const result = await api('/login', { method: 'POST', body: JSON.stringify({ username: form.get('username'), password: form.get('password') }) }); csrf = result.csrf_token; role = result.role; $('identity').textContent = result.user.username; $('role').textContent = role; show('login-panel', false); show('app-panel', true); show('logout', true); show('users-tab', role === 'L3'); await refresh(renderGroups, 'group-error'); if (role === 'L3') await refresh(renderUsers, 'user-error'); } catch (error) { $('login-error').textContent = error.message; } });
  $('logout').addEventListener('click', async () => { try { await api('/logout', { method: 'POST', body: '{}' }); } finally { csrf = ''; show('app-panel', false); show('logout', false); show('login-panel', true); } });
  $('refresh-groups').addEventListener('click', () => refresh(renderGroups, 'group-error')); $('refresh-users').addEventListener('click', () => refresh(renderUsers, 'user-error'));
  document.querySelectorAll('[data-tab]').forEach((button) => button.addEventListener('click', () => { document.querySelectorAll('[data-tab]').forEach((item) => item.classList.toggle('active', item === button)); show('groups-view', button.dataset.tab === 'groups'); show('users-view', button.dataset.tab === 'users'); }));
  fetch('/KairosAdmin/api/me', { credentials: 'same-origin' }).then(async (response) => { if (!response.ok) return; const result = await response.json(); csrf = result.csrf_token; role = result.role; $('identity').textContent = result.user.username; $('role').textContent = role; show('login-panel', false); show('app-panel', true); show('logout', true); show('users-tab', role === 'L3'); await refresh(renderGroups, 'group-error'); if (role === 'L3') await refresh(renderUsers, 'user-error'); }).catch(() => {});
})();
