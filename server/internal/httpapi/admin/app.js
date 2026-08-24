(() => {
  let csrf = '';
  let role = '';
  const $ = (id) => document.getElementById(id);
  const show = (id, visible) => $(id).classList.toggle('hidden', !visible);
  const node = (tag, className, value) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (value !== undefined) element.textContent = value;
    return element;
  };
  const button = (label, action, className = '') => {
    const element = node('button', className, label);
    element.type = 'button';
    element.addEventListener('click', async () => {
      element.disabled = true;
      try { await action(); } catch (error) { window.alert(error.message); }
      finally { element.disabled = false; }
    });
    return element;
  };
  const api = async (path, options = {}) => {
    const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
    if (csrf && options.method && options.method !== 'GET') headers['X-CSRF-Token'] = csrf;
    const response = await fetch('/KairosAdmin/api' + path, {
      credentials: 'same-origin', ...options, headers,
    });
    const body = response.status === 204 ? null : await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body?.message || '请求失败');
    return body;
  };
  const mutate = (path, method, body) => api(path, { method, body: JSON.stringify(body || {}) });
  const refresh = async (fn, errorId) => {
    try { $(errorId).textContent = ''; await fn(); }
    catch (error) { $(errorId).textContent = error.message; }
  };

  const accountRow = (group, account) => {
    const row = node('div', 'account');
    const main = node('div', 'account-main');
    const identity = node('div');
    identity.append(node('strong', '', account.display_name));
    identity.append(node('div', 'meta', `${account.account_code} · ${account.username || '未绑定'}`));
    main.append(identity, node('span', 'badge', account.role + (account.active ? '' : ' · 停用')));
    row.append(main);
    const actions = node('div', 'actions');
    actions.append(button(account.role === 'L2' ? '设为 L1' : '设为 L2', async () => {
      await mutate(`/groups/${group.id}/accounts/${account.id}/role`, 'PUT', {
        role: account.role === 'L2' ? 'L1' : 'L2',
      });
      await renderGroups();
    }, 'quiet'));
    if (account.username) {
      actions.append(button('解除绑定', async () => {
        if (!window.confirm(`解除 ${account.display_name} 与 ${account.username} 的绑定？`)) return;
        await mutate(`/groups/${group.id}/accounts/${account.id}/unbind`, 'POST', { reason: 'KairosAdmin' });
        await renderGroups();
      }, 'danger'));
    } else {
      const form = node('form', 'compact-form');
      const label = node('label', '', '精确账号名');
      const input = node('input'); input.name = 'username'; input.required = true;
      label.append(input); form.append(label, node('button', '', '绑定账号'));
      form.addEventListener('submit', async (event) => {
        event.preventDefault(); const submit = form.querySelector('button'); submit.disabled = true;
        try {
          await mutate(`/groups/${group.id}/accounts/${account.id}/bind`, 'POST', {
            username: new FormData(form).get('username'),
          });
          await renderGroups();
        } catch (error) { window.alert(error.message); }
        finally { submit.disabled = false; }
      });
      actions.append(form);
    }
    row.append(actions);
    return row;
  };

  const groupItem = async (group) => {
    const item = node('article', 'item');
    const head = node('div', 'item-head');
    head.append(node('strong', '', group.name), node('span', 'badge', group.collaboration_enabled_at ? '协作已开启' : '协作关闭'));
    item.append(head, node('div', 'meta', `群组 ID ${group.id}`));
    const groupActions = node('div', 'actions');
    if (!group.collaboration_enabled_at) {
      groupActions.append(button('开启协作', async () => {
        if (!window.confirm('协作开启后不能关闭。确定开启？')) return;
        await mutate(`/groups/${group.id}/collaboration`, 'POST'); await renderGroups();
      }));
    }
    item.append(groupActions);
    const form = node('form', 'action-form');
    for (const [name, title] of [['account_code', '花名册编号'], ['display_name', '显示名称']]) {
      const label = node('label', '', title); const input = node('input');
      input.name = name; input.required = true; label.append(input); form.append(label);
    }
    const roleLabel = node('label', '', '角色'); const select = node('select'); select.name = 'role';
    for (const value of ['L1', 'L2']) { const option = node('option', '', value); option.value = value; select.append(option); }
    roleLabel.append(select); form.append(roleLabel, node('button', '', '添加花名册账号'));
    form.addEventListener('submit', async (event) => {
      event.preventDefault(); const submit = form.querySelector('button'); submit.disabled = true;
      try { await mutate(`/groups/${group.id}/accounts`, 'POST', Object.fromEntries(new FormData(form))); await renderGroups(); }
      catch (error) { window.alert(error.message); } finally { submit.disabled = false; }
    });
    item.append(form);
    const accounts = node('div', 'accounts', '加载花名册中...'); item.append(accounts);
    try {
      const result = await api(`/groups/${group.id}/accounts`); accounts.replaceChildren();
      for (const account of result.accounts || []) accounts.append(accountRow(group, account));
      if (!result.accounts?.length) accounts.textContent = '暂无花名册账号';
    } catch (error) { accounts.textContent = error.message; }
    return item;
  };

  const renderGroups = async () => {
    const container = $('groups'); container.replaceChildren(); const data = await api('/groups');
    for (const group of data.groups || []) container.append(await groupItem(group));
    if (!data.groups?.length) container.textContent = '暂无可管理群组';
  };
  const renderUsers = async () => {
    const container = $('users'); container.replaceChildren(); const data = await api('/users');
    for (const user of data.users || []) {
      const item = node('article', 'item'); const head = node('div', 'item-head');
      head.append(node('strong', '', user.username), node('span', 'badge', user.disabled_at ? '已停用' : (user.role || 'L1')));
      item.append(head, node('div', 'meta', user.id)); const actions = node('div', 'actions');
      actions.append(button(user.disabled_at ? '启用账号' : '停用账号', async () => {
        if (!user.disabled_at && !window.confirm(`停用账号 ${user.username}？`)) return;
        await mutate(`/users/${user.id}/disabled`, 'PUT', { disabled: !user.disabled_at }); await renderUsers();
      }, user.disabled_at ? 'quiet' : 'danger'));
      actions.append(button(user.role === 'L3' ? '撤销 L3' : '授予 L3', async () => {
        if (!window.confirm(`${user.role === 'L3' ? '撤销' : '授予'} ${user.username} 的 L3 权限？`)) return;
        await mutate(`/users/${user.id}/super-admin`, 'PUT', { active: user.role !== 'L3' }); await renderUsers();
      }, 'quiet'));
      item.append(actions); container.append(item);
    }
    if (!data.users?.length) container.textContent = '暂无服务器账号';
  };

  $('create-group-form').addEventListener('submit', async (event) => {
    event.preventDefault(); const submit = event.currentTarget.querySelector('button'); submit.disabled = true;
    try { await mutate('/groups', 'POST', { name: new FormData(event.currentTarget).get('name') }); event.currentTarget.reset(); await renderGroups(); }
    catch (error) { $('group-error').textContent = error.message; } finally { submit.disabled = false; }
  });
  $('create-user-form').addEventListener('submit', async (event) => {
    event.preventDefault(); const submit = event.currentTarget.querySelector('button'); submit.disabled = true;
    try { await mutate('/users', 'POST', Object.fromEntries(new FormData(event.currentTarget))); event.currentTarget.reset(); await renderUsers(); }
    catch (error) { $('user-error').textContent = error.message; } finally { submit.disabled = false; }
  });
  $('login-form').addEventListener('submit', async (event) => {
    event.preventDefault(); $('login-error').textContent = ''; const form = new FormData(event.currentTarget);
    try {
      const result = await mutate('/login', 'POST', { username: form.get('username'), password: form.get('password') });
      csrf = result.csrf_token; role = result.role; $('identity').textContent = result.user.username; $('role').textContent = role;
      show('login-panel', false); show('app-panel', true); show('logout', true); show('users-tab', role === 'L3');
      await refresh(renderGroups, 'group-error'); if (role === 'L3') await refresh(renderUsers, 'user-error');
    } catch (error) { $('login-error').textContent = error.message; }
  });
  $('logout').addEventListener('click', async () => {
    try { await mutate('/logout', 'POST'); }
    finally { csrf = ''; show('app-panel', false); show('logout', false); show('login-panel', true); }
  });
  $('refresh-groups').addEventListener('click', () => refresh(renderGroups, 'group-error'));
  $('refresh-users').addEventListener('click', () => refresh(renderUsers, 'user-error'));
  document.querySelectorAll('[data-tab]').forEach((tab) => tab.addEventListener('click', () => {
    document.querySelectorAll('[data-tab]').forEach((item) => item.classList.toggle('active', item === tab));
    show('groups-view', tab.dataset.tab === 'groups'); show('users-view', tab.dataset.tab === 'users');
  }));
  api('/me').then(async (result) => {
    csrf = result.csrf_token; role = result.role; $('identity').textContent = result.user.username; $('role').textContent = role;
    show('login-panel', false); show('app-panel', true); show('logout', true); show('users-tab', role === 'L3');
    await refresh(renderGroups, 'group-error'); if (role === 'L3') await refresh(renderUsers, 'user-error');
  }).catch(() => {});
})();
