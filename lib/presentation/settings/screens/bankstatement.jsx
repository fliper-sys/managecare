import React, { useState } from 'react';
import { Upload, DollarSign, TrendingUp, TrendingDown, FileText, X } from 'lucide-react';
import Papa from 'papaparse';

export default function BankStatementAnalyzer() {
  const [files, setFiles] = useState([]);
  const [data, setData] = useState([]);
  const [summary, setSummary] = useState(null);
  const [selectedAccount, setSelectedAccount] = useState('all');
  const [loading, setLoading] = useState(false);

  const handleFileUpload = (e) => {
    const uploadedFiles = Array.from(e.target.files);
    setLoading(true);
    
    const allData = [];
    let filesProcessed = 0;

    uploadedFiles.forEach((file) => {
      Papa.parse(file, {
        header: true,
        dynamicTyping: true,
        skipEmptyLines: true,
        complete: (result) => {
          const parsed = result.data.map(row => ({
            ...row,
            fileName: file.name
          }));
          allData.push(...parsed);
          filesProcessed++;

          if (filesProcessed === uploadedFiles.length) {
            setFiles(prev => [...prev, ...uploadedFiles]);
            setData(prev => [...prev, ...allData]);
            analyzeData([...data, ...allData]);
            setLoading(false);
          }
        },
        error: (error) => {
          console.error('Parse error:', error);
          setLoading(false);
        }
      });
    });
  };

  const analyzeData = (records) => {
    if (!records.length) return;

    // Detect column names (flexible matching)
    const sampleRow = records[0];
    const keys = Object.keys(sampleRow);
    
    const amountCol = keys.find(k => 
      k.toLowerCase().includes('amount') || 
      k.toLowerCase().includes('value') ||
      k.toLowerCase().includes('transaction')
    );
    
    const descCol = keys.find(k => 
      k.toLowerCase().includes('description') || 
      k.toLowerCase().includes('desc') ||
      k.toLowerCase().includes('memo') ||
      k.toLowerCase().includes('detail')
    );

    const accountCol = keys.find(k =>
      k.toLowerCase().includes('account') ||
      k.toLowerCase().includes('from') ||
      k.toLowerCase().includes('to')
    );

    // Calculate totals
    let totalReceived = 0;
    let totalSent = 0;
    const accountStats = {};
    const transactions = [];

    records.forEach(row => {
      let amount = 0;
      
      if (amountCol && row[amountCol] != null) {
        amount = typeof row[amountCol] === 'string' 
          ? parseFloat(row[amountCol].replace(/[^0-9.-]/g, ''))
          : parseFloat(row[amountCol]);
      }

      if (isNaN(amount)) amount = 0;

      const account = accountCol && row[accountCol] 
        ? String(row[accountCol]).trim() 
        : 'Unknown Account';
      
      const description = descCol && row[descCol] 
        ? String(row[descCol]) 
        : 'No description';

      if (!accountStats[account]) {
        accountStats[account] = { received: 0, sent: 0, count: 0 };
      }

      if (amount > 0) {
        totalReceived += amount;
        accountStats[account].received += amount;
      } else if (amount < 0) {
        totalSent += Math.abs(amount);
        accountStats[account].sent += Math.abs(amount);
      }

      accountStats[account].count++;
      
      transactions.push({
        account,
        amount,
        description,
        fileName: row.fileName
      });
    });

    setSummary({
      totalReceived,
      totalSent,
      netBalance: totalReceived - totalSent,
      accountStats,
      transactions,
      totalTransactions: records.length
    });
  };

  const removeFile = (index) => {
    const newFiles = files.filter((_, i) => i !== index);
    const removedFileName = files[index].name;
    const newData = data.filter(row => row.fileName !== removedFileName);
    
    setFiles(newFiles);
    setData(newData);
    
    if (newData.length > 0) {
      analyzeData(newData);
    } else {
      setSummary(null);
      setSelectedAccount('all');
    }
  };

  const clearAll = () => {
    setFiles([]);
    setData([]);
    setSummary(null);
    setSelectedAccount('all');
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  const getFilteredStats = () => {
    if (!summary) return null;
    
    if (selectedAccount === 'all') {
      return {
        received: summary.totalReceived,
        sent: summary.totalSent,
        net: summary.netBalance,
        count: summary.totalTransactions
      };
    }
    
    const accountData = summary.accountStats[selectedAccount];
    return {
      received: accountData.received,
      sent: accountData.sent,
      net: accountData.received - accountData.sent,
      count: accountData.count
    };
  };

  const filteredStats = getFilteredStats();

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50">
      <div className="max-w-7xl mx-auto p-6 space-y-6">
        {/* Header */}
        <div className="text-center space-y-2 py-8">
          <h1 className="text-4xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
            Bank Statement Analyzer
          </h1>
          <p className="text-gray-600">Upload your CSV bank statements for instant financial insights</p>
        </div>

        {/* Upload Section */}
        <div className="bg-white rounded-2xl shadow-lg p-8 border border-gray-100">
          <label className="flex flex-col items-center justify-center border-2 border-dashed border-indigo-300 rounded-xl p-12 cursor-pointer hover:border-indigo-500 hover:bg-indigo-50 transition-all">
            <Upload className="w-16 h-16 text-indigo-500 mb-4" />
            <span className="text-lg font-semibold text-gray-700 mb-2">
              Drop CSV files here or click to browse
            </span>
            <span className="text-sm text-gray-500">Support for multiple files</span>
            <input
              type="file"
              accept=".csv"
              multiple
              onChange={handleFileUpload}
              className="hidden"
            />
          </label>

          {files.length > 0 && (
            <div className="mt-6 space-y-2">
              <div className="flex justify-between items-center mb-2">
                <span className="text-sm font-semibold text-gray-700">Uploaded Files:</span>
                <button
                  onClick={clearAll}
                  className="text-sm text-red-600 hover:text-red-700 font-medium"
                >
                  Clear All
                </button>
              </div>
              {files.map((file, idx) => (
                <div key={idx} className="flex items-center justify-between bg-indigo-50 rounded-lg px-4 py-2">
                  <div className="flex items-center gap-2">
                    <FileText className="w-4 h-4 text-indigo-600" />
                    <span className="text-sm text-gray-700">{file.name}</span>
                  </div>
                  <button
                    onClick={() => removeFile(idx)}
                    className="text-gray-400 hover:text-red-600 transition-colors"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {loading && (
          <div className="text-center py-8">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-4 border-indigo-500 border-t-transparent"></div>
            <p className="mt-4 text-gray-600">Processing your statements...</p>
          </div>
        )}

        {summary && !loading && (
          <>
            {/* Account Filter */}
            <div className="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
              <label className="block text-sm font-semibold text-gray-700 mb-3">
                Filter by Account
              </label>
              <select
                value={selectedAccount}
                onChange={(e) => setSelectedAccount(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              >
                <option value="all">All Accounts</option>
                {Object.keys(summary.accountStats).map(account => (
                  <option key={account} value={account}>{account}</option>
                ))}
              </select>
            </div>

            {/* Summary Cards */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-gradient-to-br from-green-500 to-emerald-600 rounded-2xl shadow-lg p-6 text-white">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-green-100">Total Received</span>
                  <TrendingUp className="w-6 h-6" />
                </div>
                <div className="text-3xl font-bold">{formatCurrency(filteredStats.received)}</div>
                <div className="text-sm text-green-100 mt-2">{filteredStats.count} transactions</div>
              </div>

              <div className="bg-gradient-to-br from-red-500 to-pink-600 rounded-2xl shadow-lg p-6 text-white">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-red-100">Total Sent</span>
                  <TrendingDown className="w-6 h-6" />
                </div>
                <div className="text-3xl font-bold">{formatCurrency(filteredStats.sent)}</div>
                <div className="text-sm text-red-100 mt-2">Outgoing payments</div>
              </div>

              <div className={`bg-gradient-to-br ${filteredStats.net >= 0 ? 'from-blue-500 to-indigo-600' : 'from-orange-500 to-red-600'} rounded-2xl shadow-lg p-6 text-white`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-blue-100">Net Balance</span>
                  <DollarSign className="w-6 h-6" />
                </div>
                <div className="text-3xl font-bold">{formatCurrency(filteredStats.net)}</div>
                <div className="text-sm text-blue-100 mt-2">
                  {filteredStats.net >= 0 ? 'Surplus' : 'Deficit'}
                </div>
              </div>
            </div>

            {/* Account Breakdown */}
            {selectedAccount === 'all' && (
              <div className="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
                <h2 className="text-2xl font-bold text-gray-800 mb-6">Account Breakdown</h2>
                <div className="space-y-4">
                  {Object.entries(summary.accountStats).map(([account, stats]) => (
                    <div key={account} className="border border-gray-200 rounded-xl p-5 hover:shadow-md transition-shadow">
                      <h3 className="font-semibold text-lg text-gray-800 mb-3">{account}</h3>
                      <div className="grid grid-cols-3 gap-4">
                        <div>
                          <span className="text-sm text-gray-500">Received</span>
                          <div className="text-lg font-bold text-green-600">{formatCurrency(stats.received)}</div>
                        </div>
                        <div>
                          <span className="text-sm text-gray-500">Sent</span>
                          <div className="text-lg font-bold text-red-600">{formatCurrency(stats.sent)}</div>
                        </div>
                        <div>
                          <span className="text-sm text-gray-500">Net</span>
                          <div className={`text-lg font-bold ${stats.received - stats.sent >= 0 ? 'text-blue-600' : 'text-orange-600'}`}>
                            {formatCurrency(stats.received - stats.sent)}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}