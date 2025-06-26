import React, { useState, useEffect } from 'react';

export const TelaLocalZIP: React.FC = () => {
  const [zipFiles, setZipFiles] = useState<string[]>([]);
  const [selectedFile, setSelectedFile] = useState<string | null>(null);
  const [nomeProprio, setNomeProprio] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [processStatus, setProcessStatus] = useState<string | null>(null);

  useEffect(() => {
    const fetchFiles = async () => {
      try {
        const res = await fetch('/api/v1/uploads/list');
        const data = await res.json();
        setZipFiles(data.files || []);
      } catch (err) {
        setZipFiles([]);
      }
    };
    fetchFiles();
  }, []);

  const handleProcess = async () => {
    if (!selectedFile) return;
    setIsProcessing(true);
    setProcessStatus(null);
    try {
      const res = await fetch('/api/v1/uploads/process', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: selectedFile, nomeProprio })
      });
      const data = await res.json();
      if (data.success) {
        setProcessStatus('Processamento iniciado com sucesso!');
      } else {
        setProcessStatus(data.error || 'Erro ao iniciar processamento');
      }
    } catch (err) {
      setProcessStatus('Erro ao iniciar processamento');
    }
    setIsProcessing(false);
  };

  return (
    <div style={{ padding: 24 }}>
      <h2 style={{ color: '#E0E1E6', fontSize: 22, fontWeight: 600, marginBottom: 16 }}>Processar ZIP Local</h2>
      <div style={{ marginBottom: 16 }}>
        <label style={{ color: '#A5A8B1', fontWeight: 500 }}>Nome próprio para detecção:</label>
        <input
          type="text"
          value={nomeProprio}
          onChange={e => setNomeProprio(e.target.value)}
          placeholder="Digite o nome próprio"
          style={{ marginLeft: 8, padding: 6, borderRadius: 6, border: '1px solid #1B263B', background: '#162332', color: '#E0E1E6' }}
        />
      </div>
      <div style={{ marginBottom: 24 }}>
        <label style={{ color: '#A5A8B1', fontWeight: 500 }}>Selecione um arquivo ZIP:</label>
        <select
          value={selectedFile || ''}
          onChange={e => setSelectedFile(e.target.value)}
          style={{ marginLeft: 8, padding: 6, borderRadius: 6, border: '1px solid #1B263B', background: '#162332', color: '#E0E1E6' }}
        >
          <option value="">Selecione...</option>
          {zipFiles.map(f => (
            <option key={f} value={f}>{f}</option>
          ))}
        </select>
      </div>
      <button
        onClick={handleProcess}
        disabled={!selectedFile || isProcessing}
        style={{ padding: '10px 24px', background: '#00ade0', color: 'white', border: 'none', borderRadius: 8, fontWeight: 600, fontSize: 16, cursor: isProcessing ? 'not-allowed' : 'pointer' }}
      >
        {isProcessing ? 'Processando...' : 'Processar'}
      </button>
      {processStatus && (
        <div style={{ marginTop: 24, color: processStatus.includes('sucesso') ? '#10b981' : '#ef4444', fontWeight: 500 }}>
          {processStatus}
        </div>
      )}
    </div>
  );
}; 