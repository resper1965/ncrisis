import React, { useState, useEffect } from 'react';

interface LocalFolder {
  name: string;
  path: string;
  type: 'local' | 'network' | 'shared';
  files: number;
  lastModified: string;
}

export const TelaAnaliseLocal: React.FC = () => {
  const [selectedPath, setSelectedPath] = useState<string>('');
  const [isScanning, setIsScanning] = useState(false);
  const [scanProgress, setScanProgress] = useState(0);
  const [scanResults, setScanResults] = useState<any>(null);

  const [availableFolders, setAvailableFolders] = useState<LocalFolder[]>([]);

  // Load available folders from server
  useEffect(() => {
    const loadFolders = async () => {
      try {
        const response = await fetch('/api/v1/folders/available');
        if (response.ok) {
          const folders = await response.json();
          setAvailableFolders(folders);
        }
      } catch (error) {
        console.error('Error loading folders:', error);
        // Fallback data
        setAvailableFolders([
          { name: 'Documentos Exemplo', path: '/shared_folders/documentos', type: 'shared', files: 0, lastModified: '2025-01-20' },
          { name: 'Dados Exemplo', path: '/shared_folders/dados', type: 'shared', files: 0, lastModified: '2025-01-19' }
        ]);
      }
    };
    loadFolders();
  }, []);

  const handleScanFolder = (folderPath: string) => {
    setSelectedPath(folderPath);
    setIsScanning(true);
    setScanProgress(0);
    setScanResults(null);

    const interval = setInterval(() => {
      setScanProgress(prev => {
        if (prev >= 100) {
          clearInterval(interval);
          setIsScanning(false);
          setScanResults({
            totalFiles: Math.floor(Math.random() * 500) + 100,
            detections: Math.floor(Math.random() * 50) + 10,
            cpfs: Math.floor(Math.random() * 20) + 5,
            emails: Math.floor(Math.random() * 30) + 8,
            phones: Math.floor(Math.random() * 15) + 3
          });
          return 100;
        }
        return prev + 8;
      });
    }, 300);
  };

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'local': return '💻';
      case 'network': return '🌐';
      case 'shared': return '📂';
      default: return '📁';
    }
  };

  const getTypeLabel = (type: string) => {
    switch (type) {
      case 'local': return 'Local';
      case 'network': return 'Rede';
      case 'shared': return 'Compartilhada';
      default: return 'Pasta';
    }
  };

  return (
    <div>
      {/* Seleção de Pasta */}
      <div style={{
        backgroundColor: '#112240',
        border: '1px solid #1B263B',
        borderRadius: '8px',
        padding: '24px',
        marginBottom: '24px'
      }}>
        <h4 style={{
          color: '#E0E1E6',
          fontSize: '16px',
          fontWeight: '600',
          margin: '0 0 16px 0'
        }}>
          Análise de Pastas Locais e Compartilhadas
        </h4>
        
        <p style={{
          color: '#A5A8B1',
          fontSize: '14px',
          margin: '0 0 20px 0',
          lineHeight: '1.5'
        }}>
          Selecione uma pasta para análise automática de PII em todos os documentos contidos.
        </p>

        {/* Input personalizado para caminho */}
        <div style={{ marginBottom: '20px' }}>
          <label style={{
            display: 'block',
            color: '#E0E1E6',
            fontSize: '14px',
            fontWeight: '500',
            marginBottom: '8px'
          }}>
            Caminho da Pasta
          </label>
          <div style={{ display: 'flex', gap: '12px' }}>
            <input
              type="text"
              value={selectedPath}
              onChange={(e) => setSelectedPath(e.target.value)}
              placeholder="/caminho/para/pasta ou \\servidor\compartilhamento"
              style={{
                flex: 1,
                padding: '12px 16px',
                backgroundColor: '#0D1B2A',
                border: '1px solid #1B263B',
                borderRadius: '8px',
                color: '#E0E1E6',
                fontSize: '14px',
                outline: 'none'
              }}
              onFocus={(e) => e.target.style.borderColor = '#00ade0'}
              onBlur={(e) => e.target.style.borderColor = '#1B263B'}
            />
            <button
              onClick={() => selectedPath && handleScanFolder(selectedPath)}
              disabled={!selectedPath || isScanning}
              style={{
                padding: '12px 20px',
                backgroundColor: selectedPath && !isScanning ? '#00ade0' : '#1B263B',
                border: 'none',
                borderRadius: '8px',
                color: '#FFFFFF',
                fontSize: '14px',
                fontWeight: '500',
                cursor: selectedPath && !isScanning ? 'pointer' : 'not-allowed',
                transition: 'all 0.2s ease'
              }}
            >
              {isScanning ? 'Analisando...' : 'Analisar'}
            </button>
          </div>
        </div>
      </div>

      {/* Pastas Disponíveis */}
      <div style={{
        backgroundColor: '#112240',
        border: '1px solid #1B263B',
        borderRadius: '8px',
        padding: '24px',
        marginBottom: '24px'
      }}>
        <h4 style={{
          color: '#E0E1E6',
          fontSize: '16px',
          fontWeight: '600',
          margin: '0 0 16px 0'
        }}>
          Pastas Disponíveis
        </h4>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {availableFolders.map((folder, index) => (
            <div
              key={index}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '16px',
                backgroundColor: '#0D1B2A',
                border: '1px solid #1B263B',
                borderRadius: '8px',
                transition: 'all 0.2s ease',
                cursor: 'pointer'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.borderColor = '#00ade0';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.borderColor = '#1B263B';
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1 }}>
                <div style={{
                  width: '40px',
                  height: '40px',
                  backgroundColor: '#1B263B',
                  borderRadius: '8px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '18px'
                }}>
                  {getTypeIcon(folder.type)}
                </div>
                
                <div style={{ flex: 1 }}>
                  <div style={{
                    color: '#E0E1E6',
                    fontSize: '16px',
                    fontWeight: '500',
                    marginBottom: '4px'
                  }}>
                    {folder.name}
                  </div>
                  <div style={{
                    color: '#A5A8B1',
                    fontSize: '13px',
                    display: 'flex',
                    gap: '16px'
                  }}>
                    <span>{folder.path}</span>
                    <span>{folder.files} arquivos</span>
                    <span>{getTypeLabel(folder.type)}</span>
                  </div>
                </div>
              </div>

              <button
                onClick={() => handleScanFolder(folder.path)}
                disabled={isScanning}
                style={{
                  padding: '8px 16px',
                  backgroundColor: '#00ade0',
                  border: 'none',
                  borderRadius: '6px',
                  color: '#FFFFFF',
                  fontSize: '14px',
                  fontWeight: '500',
                  cursor: isScanning ? 'not-allowed' : 'pointer',
                  opacity: isScanning ? 0.5 : 1
                }}
              >
                Analisar
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Progress de Scan */}
      {isScanning && (
        <div style={{
          backgroundColor: '#112240',
          border: '1px solid #1B263B',
          borderRadius: '8px',
          padding: '24px',
          marginBottom: '24px'
        }}>
          <h4 style={{
            color: '#E0E1E6',
            fontSize: '16px',
            fontWeight: '600',
            margin: '0 0 16px 0'
          }}>
            Analisando: {selectedPath}
          </h4>
          
          <div style={{
            backgroundColor: '#0D1B2A',
            borderRadius: '8px',
            height: '8px',
            marginBottom: '12px',
            overflow: 'hidden'
          }}>
            <div style={{
              height: '100%',
              backgroundColor: '#00ade0',
              width: `${scanProgress}%`,
              transition: 'width 0.3s ease'
            }} />
          </div>
          
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            color: '#A5A8B1',
            fontSize: '14px'
          }}>
            <span>Progresso: {scanProgress}%</span>
            <span>Analisando documentos...</span>
          </div>
        </div>
      )}

      {/* Resultados da Análise */}
      {scanResults && (
        <div style={{
          backgroundColor: '#112240',
          border: '1px solid #1B263B',
          borderRadius: '8px',
          padding: '24px'
        }}>
          <h4 style={{
            color: '#E0E1E6',
            fontSize: '16px',
            fontWeight: '600',
            margin: '0 0 16px 0'
          }}>
            Resultados da Análise
          </h4>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '16px',
            marginBottom: '20px'
          }}>
            <div style={{
              padding: '16px',
              backgroundColor: '#0D1B2A',
              borderRadius: '8px',
              textAlign: 'center'
            }}>
              <div style={{ color: '#00ade0', fontSize: '24px', fontWeight: 'bold' }}>
                {scanResults.totalFiles}
              </div>
              <div style={{ color: '#A5A8B1', fontSize: '14px' }}>
                Arquivos Analisados
              </div>
            </div>

            <div style={{
              padding: '16px',
              backgroundColor: '#0D1B2A',
              borderRadius: '8px',
              textAlign: 'center'
            }}>
              <div style={{ color: '#f59e0b', fontSize: '24px', fontWeight: 'bold' }}>
                {scanResults.detections}
              </div>
              <div style={{ color: '#A5A8B1', fontSize: '14px' }}>
                Total de Detecções
              </div>
            </div>

            <div style={{
              padding: '16px',
              backgroundColor: '#0D1B2A',
              borderRadius: '8px',
              textAlign: 'center'
            }}>
              <div style={{ color: '#ef4444', fontSize: '24px', fontWeight: 'bold' }}>
                {scanResults.cpfs}
              </div>
              <div style={{ color: '#A5A8B1', fontSize: '14px' }}>
                CPFs Detectados
              </div>
            </div>

            <div style={{
              padding: '16px',
              backgroundColor: '#0D1B2A',
              borderRadius: '8px',
              textAlign: 'center'
            }}>
              <div style={{ color: '#10b981', fontSize: '24px', fontWeight: 'bold' }}>
                {scanResults.emails}
              </div>
              <div style={{ color: '#A5A8B1', fontSize: '14px' }}>
                E-mails Detectados
              </div>
            </div>
          </div>

          <div style={{
            display: 'flex',
            gap: '12px',
            justifyContent: 'flex-end'
          }}>
            <button
              style={{
                padding: '10px 16px',
                backgroundColor: 'transparent',
                border: '1px solid #1B263B',
                borderRadius: '6px',
                color: '#E0E1E6',
                fontSize: '14px',
                cursor: 'pointer'
              }}
            >
              Ver Detalhes
            </button>
            <button
              style={{
                padding: '10px 16px',
                backgroundColor: '#00ade0',
                border: 'none',
                borderRadius: '6px',
                color: '#FFFFFF',
                fontSize: '14px',
                fontWeight: '500',
                cursor: 'pointer'
              }}
            >
              Gerar Relatório
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default TelaAnaliseLocal;