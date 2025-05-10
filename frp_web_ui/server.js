/**
 * FRP服务端配置前端界面的后端服务
 * 提供API支持前端对FRP的配置、启动、停止等操作
 */

const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const { exec, spawn } = require('child_process');
const app = express();
const port = process.env.PORT || 3000;

// FRP相关路径设置
const FRP_PATH = process.env.FRP_PATH || path.join(process.env.HOME || process.env.USERPROFILE, 'frp');
const FRP_CONFIG_PATH = path.join(FRP_PATH, 'conf', 'frps.ini');
const FRP_BINARY_PATH = path.join(FRP_PATH, 'frps');

// 中间件
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname))); // 静态文件服务

// 服务状态
let frpProcess = null;
let frpStatus = 'stopped';
let serviceLog = [];

// 记录日志
function logMessage(message, type = 'info') {
    const logEntry = {
        timestamp: new Date().toISOString(),
        message,
        type
    };
    console.log(`[${type.toUpperCase()}] ${message}`);
    serviceLog.push(logEntry);
    
    // 保持日志在合理大小
    if (serviceLog.length > 100) {
        serviceLog.shift();
    }
}

// 读取FRP配置
function readFrpConfig() {
    try {
        if (fs.existsSync(FRP_CONFIG_PATH)) {
            return fs.readFileSync(FRP_CONFIG_PATH, 'utf8');
        }
        return '';
    } catch (error) {
        logMessage(`读取配置失败: ${error.message}`, 'error');
        return '';
    }
}

// 保存FRP配置
function saveFrpConfig(config) {
    try {
        // 确保目录存在
        const configDir = path.dirname(FRP_CONFIG_PATH);
        if (!fs.existsSync(configDir)) {
            fs.mkdirSync(configDir, { recursive: true });
        }
        
        fs.writeFileSync(FRP_CONFIG_PATH, config);
        logMessage(`配置已保存到 ${FRP_CONFIG_PATH}`);
        return true;
    } catch (error) {
        logMessage(`保存配置失败: ${error.message}`, 'error');
        return false;
    }
}

// 启动FRP服务
function startFrp() {
    if (frpStatus === 'running') {
        logMessage('FRP已经在运行中');
        return { success: false, message: '服务已经在运行中' };
    }
    
    try {
        // 检查文件是否存在
        if (!fs.existsSync(FRP_BINARY_PATH)) {
            logMessage(`FRP可执行文件不存在: ${FRP_BINARY_PATH}`, 'error');
            return { success: false, message: 'FRP可执行文件不存在' };
        }
        
        // 检查配置文件是否存在
        if (!fs.existsSync(FRP_CONFIG_PATH)) {
            logMessage(`FRP配置文件不存在: ${FRP_CONFIG_PATH}`, 'error');
            return { success: false, message: 'FRP配置文件不存在' };
        }
        
        // 启动FRP进程
        frpProcess = spawn(FRP_BINARY_PATH, ['-c', FRP_CONFIG_PATH]);
        
        frpProcess.stdout.on('data', (data) => {
            logMessage(`FRP输出: ${data}`);
        });
        
        frpProcess.stderr.on('data', (data) => {
            logMessage(`FRP错误: ${data}`, 'error');
        });
        
        frpProcess.on('close', (code) => {
            logMessage(`FRP进程已退出，代码: ${code}`);
            frpStatus = 'stopped';
            frpProcess = null;
        });
        
        frpStatus = 'running';
        logMessage('FRP服务已启动');
        return { success: true, message: '服务已启动' };
    } catch (error) {
        logMessage(`启动FRP失败: ${error.message}`, 'error');
        return { success: false, message: `启动失败: ${error.message}` };
    }
}

// 停止FRP服务
function stopFrp() {
    if (frpStatus !== 'running' || !frpProcess) {
        logMessage('FRP服务未运行');
        return { success: false, message: '服务未运行' };
    }
    
    try {
        frpProcess.kill();
        frpStatus = 'stopped';
        frpProcess = null;
        logMessage('FRP服务已停止');
        return { success: true, message: '服务已停止' };
    } catch (error) {
        logMessage(`停止FRP失败: ${error.message}`, 'error');
        return { success: false, message: `停止失败: ${error.message}` };
    }
}

// 检查FRP服务是否已通过systemd启动
function checkSystemdService() {
    return new Promise((resolve) => {
        exec('systemctl is-active frps', (error, stdout, stderr) => {
            if (error) {
                // systemd服务未运行或不存在
                resolve(false);
                return;
            }
            
            if (stdout.trim() === 'active') {
                logMessage('检测到FRP服务通过systemd运行中');
                resolve(true);
            } else {
                resolve(false);
            }
        });
    });
}

// API路由
app.get('/api/frp/status', async (req, res) => {
    // 先检查是否通过systemd运行
    const isSystemdActive = await checkSystemdService();
    
    // 确定状态
    let status = frpStatus;
    if (isSystemdActive) {
        status = 'running';
    }
    
    res.json({
        state: status,
        systemdActive: isSystemdActive,
        uptime: frpProcess ? Math.floor((Date.now() - frpProcess.startTime) / 1000) : 0
    });
});

app.get('/api/frp/config', (req, res) => {
    const config = readFrpConfig();
    res.json({ config });
});

app.post('/api/frp/config', (req, res) => {
    const { config } = req.body;
    
    if (!config) {
        return res.status(400).json({ success: false, message: '缺少配置内容' });
    }
    
    const saved = saveFrpConfig(config);
    
    if (saved) {
        res.json({ success: true, message: '配置已保存' });
    } else {
        res.status(500).json({ success: false, message: '保存配置失败' });
    }
});

app.post('/api/frp/start', async (req, res) => {
    // 检查是否通过systemd运行
    const isSystemdActive = await checkSystemdService();
    
    if (isSystemdActive) {
        res.json({ success: true, message: '服务通过systemd运行中' });
        return;
    }
    
    const result = startFrp();
    res.json(result);
});

app.post('/api/frp/stop', async (req, res) => {
    // 检查是否通过systemd运行
    const isSystemdActive = await checkSystemdService();
    
    if (isSystemdActive) {
        res.json({ 
            success: false, 
            message: '服务通过systemd运行，请使用 systemctl stop frps 命令停止' 
        });
        return;
    }
    
    const result = stopFrp();
    res.json(result);
});

app.post('/api/frp/restart', async (req, res) => {
    // 检查是否通过systemd运行
    const isSystemdActive = await checkSystemdService();
    
    if (isSystemdActive) {
        res.json({ 
            success: false, 
            message: '服务通过systemd运行，请使用 systemctl restart frps 命令重启' 
        });
        return;
    }
    
    stopFrp();
    setTimeout(() => {
        const result = startFrp();
        res.json(result);
    }, 1000);
});

app.get('/api/frp/logs', (req, res) => {
    res.json({ logs: serviceLog });
});

// 主页路由
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// 启动服务器
app.listen(port, () => {
    logMessage(`FRP配置界面服务已启动，访问 http://localhost:${port}`);
});