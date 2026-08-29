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
  const localDateTimeValue = (date) => {
    const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
    return local.toISOString().slice(0, 16);
  };
  const inviteState = (invite) => {
    if (invite.revoked_at) return { label: '已撤销', active: false };
    if (new Date(invite.expires_at).getTime() <= Date.now()) return { label: '已过期', active: false };
    if (invite.max_uses !== undefined && invite.use_count >= invite.max_uses) {
      return { label: '已用尽', active: false };
    }
    return { label: '可使用', active: true };
  };
  const renderInvites = async (group, accounts, container) => {
    container.textContent = '加载邀请码中...';
    try {
      const result = await api('/groups/' + group.id + '/invites');
      container.replaceChildren();
      for (const invite of result.invites || []) {
        const state = inviteState(invite);
        const row = node('div', 'invite');
        const main = node('div', 'account-main');
        const detail = node('div');
        const target = accounts.find((account) => account.id === invite.target_group_account_id);
        const usage = invite.max_uses === undefined
          ? invite.use_count + ' 次 / 不限'
          : invite.use_count + ' / ' + invite.max_uses + ' 次';
        detail.append(
          node('strong', '', target ? '花名册：' + target.display_name : '普通邀请码'),
          node('div', 'meta', usage + ' · 有效至 ' + new Date(invite.expires_at).toLocaleString()),
        );
        main.append(detail, node('span', 'badge', state.label));
        row.append(main);
        if (state.active) {
          const actions = node('div', 'actions');
          actions.append(button('撤销', async () => {
            if (!window.confirm('撤销后该邀请码立即失效，确定继续？')) return;
            await mutate('/groups/' + group.id + '/invites/' + invite.id, 'DELETE');
            await renderInvites(group, accounts, container);
          }, 'danger'));
          row.append(actions);
        }
        container.append(row);
      }
      if (!result.invites?.length) container.textContent = '暂无邀请码';
    } catch (error) {
      container.textContent = error.message;
    }
  };
  const inviteManager = (group, accounts) => {
    const section = node('section', 'subsection');
    section.append(node('h3', '', '邀请码'));
    const form = node('form', 'action-form invite-form');

    const expiryLabel = node('label', '', '有效至');
    const expiry = node('input');
    expiry.name = 'expires_at'; expiry.type = 'datetime-local'; expiry.required = true; expiry.step = '60';
    const now = new Date();
    expiry.min = localDateTimeValue(new Date(now.getTime() + 60000));
    expiry.max = localDateTimeValue(new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000));
    expiry.value = localDateTimeValue(new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000));
    expiryLabel.append(expiry);

    const usesLabel = node('label', '', '最多使用次数');
    const uses = node('input');
    uses.name = 'max_uses'; uses.type = 'number'; uses.min = '1'; uses.step = '1';
    uses.placeholder = '留空表示不限次数';
    usesLabel.append(uses);

    const targetLabel = node('label', '', '认领花名册账号');
    const target = node('select');
    target.name = 'target_group_account_id';
    const ordinary = node('option', '', '不指定');
    ordinary.value = '';
    target.append(ordinary);
    for (const account of accounts.filter((item) => item.active && !item.username)) {
      const option = node('option', '', account.display_name + ' · ' + account.account_code);
      option.value = account.id;
      target.append(option);
    }
    target.addEventListener('change', () => {
      if (target.value) {
        uses.dataset.previous = uses.value;
        uses.value = '1';
        uses.disabled = true;
      } else {
        uses.disabled = false;
        uses.value = uses.dataset.previous || '';
      }
    });
    targetLabel.append(target);

    const submit = node('button', '', '生成邀请码');
    form.append(expiryLabel, usesLabel, targetLabel, submit);
    const result = node('div', 'invite-result hidden');
    const list = node('div', 'invites');
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      submit.disabled = true;
      try {
        const payload = { expires_at: new Date(expiry.value).toISOString() };
        if (target.value) {
          payload.target_group_account_id = target.value;
          payload.max_uses = 1;
        } else if (uses.value) {
          payload.max_uses = Number(uses.value);
        }
        const created = await mutate('/groups/' + group.id + '/invites', 'POST', payload);
        const code = node('code', '', created.code);
        const copy = button('复制', async () => {
          try {
            await navigator.clipboard.writeText(created.code);
            copy.textContent = '已复制';
          } catch (_) {
            window.prompt('复制邀请码', created.code);
          }
        }, 'quiet');
        result.replaceChildren(node('span', 'label', '新邀请码'), code, copy);
        result.classList.remove('hidden');
        form.reset();
        expiry.value = localDateTimeValue(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
        uses.disabled = false;
        await renderInvites(group, accounts, list);
      } catch (error) {
        window.alert(error.message);
      } finally {
        submit.disabled = false;
      }
    });
    section.append(form, result, list);
    void renderInvites(group, accounts, list);
    return section;
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
    head.append(node('strong', '', group.name), node('span', 'badge', group.archived ? '已停用' : (group.collaboration_enabled_at ? '协作已开启' : '协作关闭')));
    item.append(head, node('div', 'meta', `群组 ID ${group.id}`));
    const groupActions = node('div', 'actions');
    groupActions.append(button(group.archived ? '恢复群组' : '停用群组', async () => {
      const action = group.archived ? '恢复' : '停用';
      if (!window.confirm(`${action}群组 ${group.name}？`)) return;
      await mutate(`/groups/${group.id}/archived`, 'PUT', { archived: !group.archived });
      await renderGroups();
    }, group.archived ? 'quiet' : 'danger'));
    if (role === 'L3') {
      groupActions.append(button('删除群组', async () => {
        if (!window.confirm(`删除群组 ${group.name}？服务端数据将永久删除，本地数据不会自动删除。`)) return;
        await mutate(`/groups/${group.id}`, 'DELETE');
        await renderGroups();
      }, 'danger'));
    }
    if (!group.archived && !group.collaboration_enabled_at) {
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
    let accountValues = [];
    try {
      const result = await api(`/groups/${group.id}/accounts`); accounts.replaceChildren();
      accountValues = result.accounts || [];
      for (const account of accountValues) accounts.append(accountRow(group, account));
      if (!result.accounts?.length) accounts.textContent = '暂无花名册账号';
    } catch (error) { accounts.textContent = error.message; }
    item.append(inviteManager(group, accountValues));
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
    const form = event.currentTarget;
    try { await mutate('/groups', 'POST', { name: new FormData(form).get('name') }); form.reset(); await renderGroups(); }
    catch (error) { $('group-error').textContent = error.message; } finally { submit.disabled = false; }
  });
  $('create-user-form').addEventListener('submit', async (event) => {
    event.preventDefault(); const submit = event.currentTarget.querySelector('button'); submit.disabled = true;
    const form = event.currentTarget;
    try { await mutate('/users', 'POST', Object.fromEntries(new FormData(form))); form.reset(); await renderUsers(); }
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
