/**
 * FRP 服务端配置界面脚本
 * 实现配置管理、服务控制和状态监控功能
 */

// 全局变量
let configData = {};
let operationLogsContent = "# 操作日志初始化\n";

// DOM加载完成后执行
document.addEventListener('DOMContentLoaded', () => {
    // 初始化界面
    initUI();
    
    // 绑定事件处理器
    bindEventHandlers();
    
    // 检查服务状态
    checkServiceStatus();
    
    // 从本地存储加载配置（如果有）
    loadSavedConfig();
    
    // 生成配置文件预览
    updateConfigPreview();
    
    // 初始化日志
    appendToLogs("界面初始化完成");
});

/**
 * 初始化UI元素状态
 */
function initUI() {
    // 仪表盘开关初始化
    const enableDashboard = document.getElementById('enableDashboard');
    const dashboardSettings = document.querySelector('.dashboard-settings');
    
    enableDashboard.addEventListener('change', () => {
        dashboardSettings.style.display = enableDashboard.checked ? 'block' : 'none';
    });
    
    // 初始检查仪表盘设置状态
    dashboardSettings.style.display = enableDashboard.checked ? 'block' : 'none';
}

/**
 * 绑定所有事件处理器
 */
function bindEventHandlers() {
    // 表单提交处理
    const configForm = document.getElementById('frpConfigForm');
    configForm.addEventListener('submit', handleFormSubmit);
    
    // 生成令牌按钮点击
    document.getElementById('generateToken').addEventListener('click', generateRandomToken);
    
    // 重置按钮点击
    document.getElementById('resetBtn').addEventListener('click', resetForm);
    
    // 复制配置按钮点击
    document.getElementById('copyConfigBtn').addEventListener('click', copyConfigToClipboard);
    
    // 服务控制按钮点击
    document.getElementById('startServiceBtn').addEventListener('click', () => controlService('start'));
    document.getElementById('stopServiceBtn').addEventListener('click', () => controlService('stop'));
    document.getElementById('restartServiceBtn').addEventListener('click', () => controlService('restart'));
}

/**
 * 处理表单提交
 * @param {Event} event 提交事件
 */
function handleFormSubmit(event) {
    event.preventDefault();
    
    // 获取表单数据
    const formData = new FormData(event.target);
    const formDataObj = {};
    
    // 转换FormData为对象
    for (const [key, value] of formData.entries()) {
        // 处理复选框
        if (event.target.elements[key].type === 'checkbox') {
            formDataObj[key] = event.target.elements[key].checked;
        } 
        // 处理数字输入
        else if (event.target.elements[key].type === 'number') {
            formDataObj[key] = parseInt(value) || 0;
        }
        // 处理其他类型
        else {
            formDataObj[key] = value;
        }
    }
    
    // 保存配置
    saveConfig(formDataObj);
    
    // 生成配置文件预览
    updateConfigPreview();
    
    // 显示保存成功通知
    showToast('成功', '配置已保存', 'success');
    
    // 记录日志
    appendToLogs("配置已保存");
}

/**
 * 生成随机令牌
 */
function generateRandomToken() {
    const tokenInput = document.getElementById('token');
    const tokenLength = 32;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+';
    let token = '';
    
    for (let i = 0; i < tokenLength; i++) {
        token += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    
    tokenInput.value = token;
    appendToLogs("已生成随机令牌");
}

/**
 * 重置表单
 */
function resetForm() {
    document.getElementById('frpConfigForm').reset();
    appendToLogs("表单已重置");
    showToast('提示', '表单已重置为默认值', 'info');
}

/**
 * 保存配置
 * @param {Object} config 配置对象
 */
function saveConfig(config) {
    configData = config;
    
    // 保存到本地存储
    try {
        localStorage.setItem('frpConfig', JSON.stringify(config));
    } catch (e) {
        console.error('保存配置到本地存储失败', e);
    }
    
    // TODO: 将来可以添加保存到服务端的功能
    saveConfigToServer(config);
}

/**
 * 将配置保存到服务器
 * @param {Object} config 配置对象
 */
function saveConfigToServer(config) {
    // 模拟API请求
    setTimeout(() => {
        appendToLogs("配置已保存到服务器");
    }, 500);
}

/**
 * 从本地存储加载配置
 */
function loadSavedConfig() {
    try {
        const savedConfig = localStorage.getItem('frpConfig');
        if (savedConfig) {
            configData = JSON.parse(savedConfig);
            
            // 填充表单
            for (const [key, value] of Object.entries(configData)) {
                const element = document.getElementById(key);
                if (element) {
                    if (element.type === 'checkbox') {
                        element.checked = value;
                    } else {
                        element.value = value;
                    }
                }
            }
            
            appendToLogs("从本地存储加载了配置");
        } else {
            appendToLogs("没有找到已保存的配置，使用默认值");
        }
    } catch (e) {
        console.error('从本地存储加载配置失败', e);
        appendToLogs("从本地存储加载配置失败: " + e.message);
    }
}

/**
 * 更新配置预览
 */
function updateConfigPreview() {
    const previewElement = document.getElementById('configPreview');
    
    // 获取当前表单数据
    const formData = new FormData(document.getElementById('frpConfigForm'));
    const formObj = {};
    
    for (const [key, value] of formData.entries()) {
        formObj[key] = value;
    }
    
    // 构建配置字符串
    let configStr = "[common]\n";
    
    // 基本配置
    configStr += `bind_addr = ${formObj.bindAddr || '0.0.0.0'}\n`;
    configStr += `bind_port = ${formObj.bindPort || '7000'}\n`;
    
    if (formObj.token) {
        configStr += `token = ${formObj.token}\n`;
    }
    
    if (formObj.vhostHttpPort) {
        configStr += `vhost_http_port = ${formObj.vhostHttpPort}\n`;
    }
    
    if (formObj.vhostHttpsPort) {
        configStr += `vhost_https_port = ${formObj.vhostHttpsPort}\n`;
    }
    
    // 仪表盘配置
    const enableDashboard = document.getElementById('enableDashboard').checked;
    if (enableDashboard) {
        configStr += `dashboard_addr = 0.0.0.0\n`;
        configStr += `dashboard_port = ${formObj.dashboardPort || '7500'}\n`;
        
        if (formObj.dashboardUser) {
            configStr += `dashboard_user = ${formObj.dashboardUser}\n`;
        }
        
        if (formObj.dashboardPass) {
            configStr += `dashboard_pwd = ${formObj.dashboardPass}\n`;
        }
    }
    
    // 高级配置
    if (document.getElementById('enableTlsOnly').checked) {
        configStr += `tls_only = true\n`;
    }
    
    if (document.getElementById('enableCompression').checked) {
        configStr += `use_compression = true\n`;
    }
    
    const maxPoolCount = parseInt(formObj.maxPoolCount);
    if (maxPoolCount > 0) {
        configStr += `max_pool_count = ${maxPoolCount}\n`;
    }
    
    const maxPortsPerClient = parseInt(formObj.maxPortsPerClient);
    if (maxPortsPerClient > 0) {
        configStr += `max_ports_per_client = ${maxPortsPerClient}\n`;
    }
    
    if (formObj.logLevel) {
        configStr += `log_level = ${formObj.logLevel}\n`;
    }
    
    const logMaxDays = parseInt(formObj.logMaxDays);
    if (logMaxDays > 0) {
        configStr += `log_max_days = ${logMaxDays}\n`;
    }
    
    // 更新预览
    previewElement.textContent = configStr;
}

/**
 * 复制配置到剪贴板
 */
function copyConfigToClipboard() {
    const configText = document.getElementById('configPreview').textContent;
    
    navigator.clipboard.writeText(configText)
        .then(() => {
            showToast('成功', '配置已复制到剪贴板', 'success');
            appendToLogs("配置已复制到剪贴板");
        })
        .catch(err => {
            showToast('错误', '复制失败: ' + err, 'error');
            appendToLogs("复制到剪贴板失败: " + err);
        });
}

/**
 * 检查FRP服务状态
 */
function checkServiceStatus() {
    const statusElement = document.getElementById('serviceStatus');
    
    // 模拟API请求
    setTimeout(() => {
        // 随机状态，实际应该从API获取
        const states = ['running', 'stopped', 'unknown'];
        const randomState = states[Math.floor(Math.random() * states.length)];
        
        updateServiceStatusUI(randomState);
        appendToLogs(`检测到FRP服务状态: ${randomState}`);
    }, 1000);
}

/**
 * 更新服务状态UI
 * @param {string} state 服务状态
 */
function updateServiceStatusUI(state) {
    const statusElement = document.getElementById('serviceStatus');
    let statusHTML = '';
    
    switch (state) {
        case 'running':
            statusHTML = `
                <div class="d-flex align-items-center">
                    <span class="status-indicator status-running"></span>
                    <span>服务正在运行</span>
                </div>
            `;
            statusElement.className = 'alert alert-success mt-3';
            break;
        case 'stopped':
            statusHTML = `
                <div class="d-flex align-items-center">
                    <span class="status-indicator status-stopped"></span>
                    <span>服务已停止</span>
                </div>
            `;
            statusElement.className = 'alert alert-danger mt-3';
            break;
        default:
            statusHTML = `
                <div class="d-flex align-items-center">
                    <span class="status-indicator status-unknown"></span>
                    <span>无法获取服务状态</span>
                </div>
            `;
            statusElement.className = 'alert alert-secondary mt-3';
    }
    
    statusElement.innerHTML = statusHTML;
    
    // 更新按钮状态
    document.getElementById('startServiceBtn').disabled = (state === 'running');
    document.getElementById('stopServiceBtn').disabled = (state === 'stopped');
    document.getElementById('restartServiceBtn').disabled = (state === 'stopped');
}

/**
 * 控制FRP服务
 * @param {string} action 操作类型：start, stop, restart
 */
function controlService(action) {
    const actionText = {
        'start': '启动',
        'stop': '停止',
        'restart': '重启'
    };
    
    appendToLogs(`正在${actionText[action]}FRP服务...`);
    showToast('处理中', `正在${actionText[action]}服务，请稍候...`, 'info');
    
    // 模拟API请求
    setTimeout(() => {
        const success = Math.random() > 0.2; // 80% 成功率
        
        if (success) {
            appendToLogs(`FRP服务${actionText[action]}成功`);
            showToast('成功', `服务已${actionText[action]}`, 'success');
            
            // 更新状态
            if (action === 'start' || action === 'restart') {
                updateServiceStatusUI('running');
            } else if (action === 'stop') {
                updateServiceStatusUI('stopped');
            }
        } else {
            appendToLogs(`FRP服务${actionText[action]}失败`);
            showToast('错误', `服务${actionText[action]}失败`, 'error');
        }
    }, 1500);
}

/**
 * 添加日志到操作日志区域
 * @param {string} message 日志消息
 */
function appendToLogs(message) {
    const timestamp = new Date().toLocaleTimeString();
    operationLogsContent += `[${timestamp}] ${message}\n`;
    
    const logsElement = document.getElementById('operationLogs');
    logsElement.textContent = operationLogsContent;
    
    // 自动滚动到底部
    logsElement.scrollTop = logsElement.scrollHeight;
}

/**
 * 显示通知提示
 * @param {string} title 标题
 * @param {string} message 消息内容
 * @param {string} type 类型：success, info, warning, error
 */
function showToast(title, message, type = 'info') {
    const toastElement = document.getElementById('liveToast');
    const toastTitle = document.getElementById('toastTitle');
    const toastMessage = document.getElementById('toastMessage');
    
    // 设置样式
    toastElement.className = 'toast';
    switch (type) {
        case 'success':
            toastElement.classList.add('text-bg-success');
            break;
        case 'warning':
            toastElement.classList.add('text-bg-warning');
            break;
        case 'error':
            toastElement.classList.add('text-bg-danger');
            break;
        default:
            toastElement.classList.add('text-bg-info');
    }
    
    // 设置内容
    toastTitle.textContent = title;
    toastMessage.textContent = message;
    
    // 显示通知
    const bsToast = new bootstrap.Toast(toastElement);
    bsToast.show();
}