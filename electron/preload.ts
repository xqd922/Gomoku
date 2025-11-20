import { contextBridge } from 'electron'

contextBridge.exposeInMainWorld('api', {
  // 预留：后续添加存档/读档、版本获取等
})

export {}

